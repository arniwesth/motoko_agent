import * as fs from "fs";
import * as path from "path";
import { randomBytes } from "crypto";
import type { AgentEvent } from "./runtime-process.js";

/**
 * Host-owned answer publication — ADR-002 v4.2 D1.2, PLAN-002 W1b.
 *
 * `--answer-file <path>` makes completion a runtime act rather than something the model has to
 * remember: the host writes the run's final `done` output to the path, and a delegate's
 * orchestrator reads that file as the completion gate (`packages/motoko-ext-herdr`,
 * `do_check_motoko`). The model is still asked to write the file itself, which is why an
 * existing non-empty file wins.
 *
 * THE RULES, verbatim from the ADR:
 *   - an existing non-empty file at the path wins;
 *   - a non-empty `done` output is written otherwise;
 *   - an empty `done`, a runtime `error`, an `abort`, or a publication failure writes nothing;
 *   - in an `--answer-file` one-shot, those four cases exit non-zero with the reason on stderr.
 *
 * "Empty" is `trim() === ""`, the one definition of blank every other site uses (PLAN-002 §0.2
 * rule 6). The existing-file rule is checked first, so a model that wrote its answer and then
 * ended on a blank turn still publishes: the answer is on disk.
 *
 * ONE WRITER, TWO CALL SITES. `index.ts` calls `publishAnswer` from the plain/JSONL callback after
 * the session logger has drained, and from the TTY callback of an `--oneshot` run before the event
 * is rendered. Both run before exit actions and before the herdr reporter's release, because both
 * are registered as `exit` listeners and nothing here exits.
 */

export type AnswerPublication =
  | { ok: true; wrote: boolean; path: string }
  | { ok: false; reason: string; path: string };

/** The exit code of an `--answer-file` one-shot that published nothing. 1 is error/suspended, 2 no task, 3 resume refused. */
export const ANSWER_UNPUBLISHED_EXIT_CODE = 4;

export interface AnswerFs {
  readFileSync(p: string, enc: "utf8"): string;
  writeFileSync(p: string, data: string, enc: "utf8"): void;
  renameSync(from: string, to: string): void;
  rmSync(p: string, opts: { force: boolean }): void;
}

function existingContent(fsImpl: AnswerFs, target: string): string {
  try {
    return fsImpl.readFileSync(target, "utf8");
  } catch {
    return "";
  }
}

/**
 * Atomic: a temp file in the destination's own directory, then a rename, so a reader polling the
 * path sees either nothing or the whole answer — the extension counts first non-empty content as
 * the answer, which is only sound because of this.
 */
function writeAtomically(fsImpl: AnswerFs, target: string, content: string): void {
  const tmp = path.join(path.dirname(target), `.${path.basename(target)}.${process.pid}.${randomBytes(4).toString("hex")}.tmp`);
  try {
    fsImpl.writeFileSync(tmp, content, "utf8");
    fsImpl.renameSync(tmp, target);
  } catch (err) {
    try {
      fsImpl.rmSync(tmp, { force: true });
    } catch {}
    throw err;
  }
}

/**
 * Publish the answer for one terminal event. Never throws; `aborted` is the host's own knowledge
 * that the operator stopped this run, which no runtime event carries.
 */
export function publishAnswer(
  target: string,
  event: AgentEvent,
  aborted: boolean,
  fsImpl: AnswerFs = fs,
): AnswerPublication {
  if (aborted) return { ok: false, reason: "the run was aborted", path: target };
  if (event.type === "error") return { ok: false, reason: `the run ended in an error: ${event.message}`, path: target };
  if (event.type !== "done") return { ok: false, reason: `the run ended on \`${event.type}\`, not \`done\``, path: target };
  if (existingContent(fsImpl, target).trim() !== "") return { ok: true, wrote: false, path: target };
  if (event.output.trim() === "") return { ok: false, reason: "the run ended with an empty `done`", path: target };
  try {
    writeAtomically(fsImpl, target, event.output);
    return { ok: true, wrote: true, path: target };
  } catch (err) {
    return { ok: false, reason: `publication failed: ${err instanceof Error ? err.message : String(err)}`, path: target };
  }
}

/** The runtime exited without a terminal event to publish from — a kill, an ESC interrupt, a crash. */
export function unpublishedOnExit(target: string, aborted: boolean): Extract<AnswerPublication, { ok: false }> {
  return {
    ok: false,
    reason: aborted ? "the run was aborted" : "the runtime exited without a `done`",
    path: target,
  };
}

/** The stderr line for an answer that was not published. */
export function formatUnpublished(p: Extract<AnswerPublication, { ok: false }>): string {
  return `[answer-file] nothing published to ${p.path}: ${p.reason}\n`;
}

/**
 * The exit code a one-shot takes on its terminal event: 0 when the answer is on disk (or no
 * `--answer-file` was asked for and the run finished), non-zero otherwise.
 */
export function oneShotExitCode(event: AgentEvent, publication: AnswerPublication | null): number {
  if (publication !== null && !publication.ok) return event.type === "error" ? 1 : ANSWER_UNPUBLISHED_EXIT_CODE;
  return event.type === "error" ? 1 : 0;
}

export interface OneShotFinish {
  /** Publication, then the UI forward — the order both callbacks keep. */
  forward(event: AgentEvent): void;
  /** The session logger's drain. The exit is taken only after it resolves (R4). */
  close(): Promise<void>;
  stopUi(): void;
  stderr(line: string): void;
  exit(code: number): void;
}

/**
 * The interactive one-shot's end (`--oneshot`, TTY): publish, render, DRAIN, exit.
 *
 * The drain is the point. `process.exit` drops a WriteStream's pending buffer, and the tail it
 * drops is `run_summary` and `done` (M-MOTOKO-EVAL-HARNESS-HARDENING gap #1) — the same reason the
 * plain/JSONL callback forwards terminal events only after `logger.close()` resolves. The
 * synchronous `logger.log(event)` before this is not a drain.
 */
export function finishOneShot(
  event: AgentEvent,
  answerFile: string | null,
  aborted: boolean,
  deps: OneShotFinish,
  fsImpl: AnswerFs = fs,
): Promise<void> {
  const publication = answerFile !== null ? publishAnswer(answerFile, event, aborted, fsImpl) : null;
  deps.forward(event);
  return deps.close().then(() => {
    deps.stopUi();
    if (publication !== null && !publication.ok) deps.stderr(formatUnpublished(publication));
    deps.exit(oneShotExitCode(event, publication));
  });
}
