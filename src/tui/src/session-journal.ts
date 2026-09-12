/**
 * THE HOST'S SESSION JOURNAL — ADR-003 v6.1 D1's entries, D3's one writer.
 *
 * `.motoko/sessions/<session_id>/journal.jsonl`, one JSON object per line, append-only, created
 * `0700`. The JSONL log under `.motoko/logfile/` is unchanged in shape and keeps carrying digests;
 * the journal carries CONTENT, and nothing in it is copied to the log.
 *
 * WHY THIS IS NOT PART OF `SessionLogger`, which is where every other wire consumer lives.
 * `SessionLogger` is constructed per child spawn (`index.ts`) and closed at child exit, and the
 * journal outlives every spawn: a `/restart`, a model switch that respawns, and P3 Part 5's
 * `--resume` are all one session with one journal, one leaf and one `seq` counter. A per-spawn
 * owner would restart the sequence and orphan the parent chain at every respawn. So the journal is
 * host-lifetime, minted beside the session id (`session-identity.ts`), and each logger is HANDED
 * it.
 *
 * THE CHILD WRITES NOTHING (PLAN-003 §0.8). Every entry here is built from a wire event the child
 * emitted, and every digest in it was computed by the child. The host computes NO digest over a
 * history — D1's third `history_seeded` arm is a comparison between two child-computed values, and
 * a host that recomputed one would be sealing the chain with its own hand.
 *
 * THE TWIN. `src/core/journal.ail`'s `journal_lines_of_records` is the pure-AILANG twin of this
 * writer: same envelope, same id assignment, same three `history_seeded` arms, same one-entry-per-
 * message expansion. It exists so the DST family and P3 Part 5's resume script can build a journal
 * from a run's own trace without a TypeScript host; this one exists because only the host holds a
 * leaf and a `seq` across a whole session. Where they disagree the FOLD is the judge — both are
 * written to be accepted by `journal.fold_journal` and neither gets to define the file alone.
 */

import * as fs from "fs";
import * as path from "path";
import { createHash } from "crypto";

/** D1's schema version. A journal the fold does not know the version of is refused, not guessed. */
export const JOURNAL_SCHEMA_VERSION = 1;

/**
 * The journal-class wire events (ADR-003 D3). These become entries; everything else on the wire is
 * logged and forgotten.
 *
 * `park_entered` and `wake_received` are ADR-003 D7's and are listed by the plan, but they DO NOT
 * EXIST — `phase_vocab.ail` declares no such `LedgerEvent` and ADR-002 D2 is not activated, so
 * nothing can emit one. Listing them here would be worse than leaving them out: `journal.ail`'s
 * `all_entry_types()` has no `park`/`wake`, and its decoder refuses an unknown `type` rather than
 * skipping it, so a `park` entry written today would make every later fold refuse the whole file.
 * They land with P4, together with the entry types that can hold them.
 */
const JOURNAL_CLASS = new Set([
  "history_seeded",
  "history_appended",
  "history_replaced",
  "state_delta",
  "session_start",
  "run_summary",
  "model_change",
  "run_suspended",
  "session_resumed",
]);

export function isJournalClass(type: string): boolean {
  return JOURNAL_CLASS.has(type);
}

type Json = Record<string, unknown>;

function str(v: unknown, fallback = ""): string {
  return typeof v === "string" ? v : fallback;
}

function num(v: unknown, fallback = 0): number {
  return typeof v === "number" && Number.isFinite(v) ? v : fallback;
}

function obj(v: unknown): Json | null {
  return v && typeof v === "object" && !Array.isArray(v) ? (v as Json) : null;
}

/** `sha256:<hex>` over a value's canonical JSON — the same prefix shape the child's digests carry. */
export function payloadDigest(value: unknown): string {
  return `sha256:${createHash("sha256").update(JSON.stringify(value ?? null)).digest("hex")}`;
}

/**
 * D1's entry id: the zero-padded `seq`, host-assigned and opaque to the child. Four digits to the
 * thousand and then however many the number needs, byte-identical to `journal.ail`'s `entry_id` so
 * a journal written by the host and one written by the twin sort and read the same way.
 */
export function entryId(seq: number): string {
  return seq < 10 ? `000${seq}` : seq < 100 ? `00${seq}` : seq < 1000 ? `0${seq}` : String(seq);
}

/** What the host knows before the first spawn. D1's `boot` is the child's and arrives later. */
export interface HeaderSeed {
  sessionId: string;
  workdir: string;
  profile: string;
  model: string;
}

/**
 * What the CHILD reports and the host cannot compute: the two compatibility digests and the loop
 * inputs D1's `boot` enumerates. `ext_set_digest` comes from the extension REGISTRY — D5 is
 * explicit that it is not derived from `session_start`'s `loaded_extensions` names, and the host
 * could only ever derive it from those.
 */
export interface HeaderCompletion {
  system_prefix_digest: string;
  ext_set_digest: string;
  boot: Json;
}

/**
 * The `boot` a header carries before the child has reported one. Every field is present and
 * honestly zero, so the header is DECODABLE from the first byte: `journal.ail`'s `boot_of_json` is
 * strict per field, and a half-written header would be refused as malformed rather than as
 * incomplete, which are two different things to tell an operator.
 */
export function emptyBoot(): Json {
  return {
    task: "",
    env_url: "",
    hybrid_tools: false,
    budget: { total: 0, solver: 0, verifier: 0 },
    step_budget: 0,
    ohmy_pi: false,
    max_cost_millicents: 0,
    cost_rates: { input_per_1m_millicents: 0, output_per_1m_millicents: 0 },
  };
}

export interface JournalOptions {
  /** Test seam for `at_ms`. The fold never reads it; a test that pins bytes does. */
  now?: () => number;
  /** Where a write failure is reported. Defaults to stderr; never throws into the wire handler. */
  onError?: (message: string) => void;
}

export class SessionJournal {
  readonly dir: string;
  readonly filePath: string;
  readonly sessionId: string;

  private seq = 0;
  /** D1's leaf: the last entry on the active branch, held in memory by the host. */
  private leaf = "";
  private headerCompleted = false;
  private readonly now: () => number;
  private readonly onError: (message: string) => void;

  /**
   * The running message count, which is what `first_kept` is an index into. D1 gives
   * `history_replaced.first_kept` as "the pre-checkpoint history index of its first kept message",
   * and one message per entry is what makes resolving it a lookup rather than a search. At HEAD
   * the checkpoint keeps no tail and always sends `None` (`apply_checkpoint` rebuilds the history
   * as the pinned system prefix plus one summary), so this is the count that lets the host REFUSE
   * an out-of-range index the day a checkpoint starts keeping one, instead of writing an entry the
   * fold would then read as a silent truncation.
   */
  private historyMessages = 0;

  /**
   * D1's `exit.pending_tool_calls`, maintained as the entries go by — the three-line TypeScript
   * twin of the fold's trailing-pair rule (D4 rule 4): the last assistant's `tool_calls` minus the
   * `tool_call_id`s of the entries after it. Kept incrementally rather than recomputed at exit
   * because the exit path is a `process.on("exit")` listener with no event loop left to read a
   * file in.
   */
  private openCallIds: string[] = [];

  /**
   * `false` until the first `history_seeded` of the session has been expanded. D1's three arms
   * turn on it: the FIRST seed of a session is the history itself and becomes N `history_appended`
   * entries; every later one is a run re-stating a history the journal already holds.
   */
  private seeded = false;

  /**
   * Set by the resumer (P3 Part 5) when the `resumed` entry it just wrote recorded a CHANGED
   * prompt digest — D1's second arm. The next `history_seeded` is then the new head after a
   * profile switch and is journaled as a `history_replaced`, which re-bases the chain. Cleared as
   * soon as it is used: it describes one seed, not a mode.
   */
  private replaceNextSeed = false;

  /** Whether anything has made this session unresumable. D1's third arm sets it on a mismatch. */
  private unresumableReason: string | null = null;

  /**
   * Whether a `history_replaced` has been journaled since the last seed. It is not used to decide
   * anything — it is used to SAY something: it is what tells a digest mismatch apart from a
   * corrupted journal, because after a checkpoint the conversation loop cannot know the chain
   * re-based (P3 Part 3's stated limitation).
   */
  private replacedSinceSeed = false;

  constructor(projectRoot: string, sessionId: string, options: JournalOptions = {}) {
    this.sessionId = sessionId;
    this.dir = path.join(projectRoot, ".motoko", "sessions", sessionId);
    this.filePath = path.join(this.dir, "journal.jsonl");
    this.now = options.now ?? Date.now;
    this.onError =
      options.onError ?? ((message) => process.stderr.write(`[journal] ${message}\n`));
    // 0700: the journal carries the conversation verbatim — every prompt, every tool output, every
    // file the model read. The log directory beside it carries digests instead, which is why this
    // one is the mode that had to be said out loud.
    fs.mkdirSync(this.dir, { recursive: true, mode: 0o700 });
    try {
      fs.chmodSync(this.dir, 0o700);
    } catch {
      // A pre-existing directory with a wider mode is a smaller problem than a session that
      // refuses to start. The mode is set on creation; this only repairs it.
    }
    this.adopt();
  }

  /**
   * ADOPT AN EXISTING JOURNAL RATHER THAN RESTART IT, and the reason is a crash.
   *
   * The `seq` counter and the leaf are held IN MEMORY (D1), which is right for a session and wrong
   * for a session's second PROCESS: after a `kill -9` the lease goes stale, the next Motoko on that
   * session id takes it over — that is the whole point of the stale-lease rule, and the second
   * judging number depends on it — and a fresh counter would then write `0000`, `0001`, … over an
   * id space the file already uses. The fold's path walk stops at the first REPEATED id, so the
   * result would not be a corrupt file; it would be a plausible one that folds a mangled path. The
   * same happens, without any crash, whenever a session directory outlives the process that made
   * it.
   *
   * MEASURED, not anticipated: the first `kill -9` run of this part's manual gate left a journal
   * with two entries at `seq: 0`, both headers.
   *
   * What is adopted is everything the writer would otherwise re-derive: the next `seq`, the leaf,
   * whether the header was completed, whether a history has been seeded, and the chain digest the
   * last history entry left. The last of those is what makes D1's third arm work across the
   * process boundary — and what makes this fail CLOSED without `--resume`: a child that starts a
   * fresh history states a seed digest that does not continue the journal's chain, the seed is
   * dropped, and the session is marked unresumable rather than having two chains spliced into one
   * file. Continuing the chain is what `--resume` is for (P3 Part 5), where the child seeds from
   * the FOLDED history and the digests line up by construction.
   */
  private adopt(): void {
    let raw: string;
    try {
      raw = fs.readFileSync(this.filePath, "utf8");
    } catch {
      return; // No journal yet: the ordinary first-start path.
    }
    const lines = raw.split("\n").filter((l) => l.trim() !== "");
    if (lines.length === 0) return;
    let adopted = 0;
    for (const line of lines) {
      let e: Json;
      try {
        e = JSON.parse(line) as Json;
      } catch {
        // A torn last line is what a crash mid-append leaves. Stop here: everything before it is
        // sound, and the next entry's `parent_id` will name the last id this loop saw.
        break;
      }
      adopted += 1;
      this.leaf = str(e.id, this.leaf);
      const type = str(e.type);
      if (type === "header") {
        this.headerCompleted = str(e.system_prefix_digest) !== "";
      } else if (type === "history_appended") {
        this.seeded = true;
        this.chainDigest = str(e.digest_after, this.chainDigest);
        if (e.replaces_previous === true) this.replaceLastHistoryMessage(e.message);
        else this.noteHistoryMessage(e.message);
      } else if (type === "history_replaced") {
        this.seeded = true;
        this.chainDigest = str(e.digest_after, this.chainDigest);
        this.historyMessages = Array.isArray(e.messages) ? e.messages.length : 0;
        this.openCallIds = [];
        this.replacedSinceSeed = true;
      } else if (type === "exit") {
        this.lastEntryWasExit = true;
      }
      if (type !== "exit") this.lastEntryWasExit = false;
      const runId = str(e.run_id);
      if (runId !== "") this.lastRunId = runId;
    }
    // `seq` is the FILE POSITION (D1), so it is the count of entries actually read — not the last
    // `seq` field plus one, which a hand-edited file could make disagree with the line count.
    this.seq = adopted;
  }

  /** The leaf D6's fold is called with. Exposed so P3 Part 5 can hand it to the child. */
  get currentLeaf(): string {
    return this.leaf;
  }

  get isHeaderCompleted(): boolean {
    return this.headerCompleted;
  }

  get unresumable(): string | null {
    return this.unresumableReason;
  }

  /** Number of entries written. The next entry's `seq`. */
  get entryCount(): number {
    return this.seq;
  }

  // --------------------------------------------------------------------------
  // The append.
  // --------------------------------------------------------------------------

  /**
   * ONE append, SYNCHRONOUS, and both halves of that are deliberate.
   *
   * D3's durability rule is "each entry is written as it arrives, so a child crash loses at most
   * the entry in flight". `appendFileSync` is what makes that true without a drain: a buffered
   * `WriteStream` would hold the tail of a session that `kill -9` is about to end — which is the
   * exact crash the second judging number resumes from — and an async write started inside a
   * `process.on("exit")` listener never runs at all (`herdr-agent-state.ts`'s release is
   * `spawnSync` for the same reason). One writer, one syscall per entry, no close() to race.
   */
  private append(type: string, payload: Json): string | null {
    const id = entryId(this.seq);
    const line = {
      id,
      parent_id: this.seq === 0 ? null : this.leaf,
      seq: this.seq,
      at_ms: this.now(),
      type,
      ...payload,
    };
    try {
      fs.appendFileSync(this.filePath, `${JSON.stringify(line)}\n`, { mode: 0o600 });
    } catch (e) {
      this.onError(`append of ${type} failed: ${String(e)}`);
      return null;
    }
    this.seq += 1;
    this.leaf = id;
    if (type !== "exit") this.lastEntryWasExit = false;
    return id;
  }

  // --------------------------------------------------------------------------
  // The header, and its ONE in-place rewrite.
  // --------------------------------------------------------------------------

  /**
   * Write the header, before the first spawn, from the values the host has.
   *
   * The digests are empty and `boot` is zeroed until the child reports them (`completeHeader`).
   * THAT IS NOT A HALF-WRITTEN FILE: every field D1 names is present and decodable, so a journal
   * whose child died before it could report has a well-formed header and NO history — and a fold
   * of it refuses, which is D3's "there is nothing to resume" reached through the history rules
   * rather than through a completeness flag the format does not carry.
   */
  writeHeader(seed: HeaderSeed): void {
    // ONE HEADER PER SESSION. `seq !== 0` is now a real test rather than a formality: a second
    // process on the same session adopts the file and starts above zero, so this is what stops it
    // writing a second root into a journal that already has one.
    if (this.seq !== 0) return;
    this.append("header", {
      schema_version: JOURNAL_SCHEMA_VERSION,
      session_id: seed.sessionId,
      workdir: seed.workdir,
      profile: seed.profile,
      ext_set_digest: "",
      model: seed.model,
      system_prefix_digest: "",
      boot: emptyBoot(),
    });
  }

  /**
   * Complete the header in place — THE ONLY in-place write the design admits (D3), and atomic.
   *
   * Rewriting one line of an append-only file means rewriting the file: the header is line 1 and
   * every later line's offset shifts with it. So the whole file is rebuilt beside itself and
   * RENAMED over the original, which on one filesystem is atomic — a reader either sees the old
   * header or the new one, never a truncated file. That is also why this happens ONCE: a second
   * rewrite would be a second window in which a `kill -9` could catch the copy.
   *
   * Idempotent, because a respawn emits its own startup event and a session has one header.
   */
  completeHeader(c: HeaderCompletion): boolean {
    if (this.headerCompleted) return false;
    let lines: string[];
    try {
      lines = fs.readFileSync(this.filePath, "utf8").split("\n");
    } catch (e) {
      this.onError(`header completion could not read the journal: ${String(e)}`);
      return false;
    }
    if (lines.length === 0 || lines[0].trim() === "") {
      this.onError("header completion found no header line");
      return false;
    }
    let header: Json;
    try {
      header = JSON.parse(lines[0]) as Json;
    } catch (e) {
      this.onError(`header completion could not parse the header: ${String(e)}`);
      return false;
    }
    if (str(header.type) !== "header") {
      this.onError(`header completion found a ${str(header.type, "(typeless)")} on line 1`);
      return false;
    }
    header.system_prefix_digest = c.system_prefix_digest;
    header.ext_set_digest = c.ext_set_digest;
    header.boot = c.boot;
    lines[0] = JSON.stringify(header);
    const tmp = `${this.filePath}.tmp`;
    try {
      fs.writeFileSync(tmp, lines.join("\n"), { mode: 0o600 });
      fs.renameSync(tmp, this.filePath);
    } catch (e) {
      try {
        fs.rmSync(tmp, { force: true });
      } catch {
        // The rename is what mattered; a leftover tmp is cosmetic.
      }
      this.onError(`header completion could not be published: ${String(e)}`);
      return false;
    }
    this.headerCompleted = true;
    return true;
  }

  // --------------------------------------------------------------------------
  // The routing. One wire event in, zero or more entries out.
  // --------------------------------------------------------------------------

  /**
   * Route one journal-class wire event. Returns the number of entries appended, which is what the
   * tests assert on: D1's arms differ by COUNT (a seed of N messages is N entries, or one, or
   * none) and a router that returned only "handled" would hide the difference.
   */
  record(event: Json): number {
    const type = str(event.type);
    if (!isJournalClass(type)) return 0;
    // Every journal-class event of a run carries the same `run_id` — P3 Part 3's payload-equality
    // rule asserts exactly that — so ANY of them can supply the one `run_summary` lacks.
    this.noteRunId(str(event.run_id));
    switch (type) {
      case "history_seeded":
        return this.recordSeed(event);
      case "history_appended":
        return this.recordAppended(event);
      case "history_replaced":
        return this.recordReplaced(event);
      case "state_delta":
        return this.recordStateDelta(event);
      case "session_start": {
        // `run_summary` carries no `run_id` — it is the run's summary and the run is the frame it
        // is in — so `run_finished` takes the id this event names, exactly as the twin does.
        const runId = str(event.run_id);
        this.noteRunId(runId);
        return this.append("run_started", { run_id: runId }) ? 1 : 0;
      }
      case "run_summary":
        return this.recordRunFinished(event);
      case "model_change":
        return this.append("settings", { model: str(event.model) }) ? 1 : 0;
      case "run_suspended":
        return this.append("suspended", {
          run_id: str(event.run_id),
          reason: str(event.reason),
          step: num(event.step),
        })
          ? 1
          : 0;
      case "session_resumed":
        return this.recordResumed(event);
      default:
        return 0;
    }
  }

  /**
   * D1's THREE ARMS for `history_seeded`, and the host computes no digest in any of them.
   *
   * 1. FIRST RUN OF THE SESSION — the seed IS the history, expanded into N `history_appended`
   *    entries, one message each. The N `digest_after` values are the chain over the seed's own
   *    messages, which the host has to produce because the event carries ONE digest for N
   *    messages; the twin does the same and says so. This is the one place the chain is not
   *    sealing a child-computed value, and it is the only place it cannot be.
   * 2. AFTER A RESUME THAT CHANGED THE PROMPT DIGEST — a profile switch replaced the whole head
   *    prefix (D6 step 4), so the seed is a NEW head and becomes a `history_replaced` that re-bases
   *    the chain. `replaceNextSeed` is set by `recordResumed` from the entry it just wrote.
   * 3. OTHERWISE — a follow-up turn re-stating the history the journal already holds. The host
   *    COMPARES the seed's `digest` with the last history entry's `digest_after`, both
   *    child-computed, and DROPS the event. A mismatch is logged and marks the session
   *    unresumable: it means the child's history and the journal's have diverged, and appending
   *    either would be choosing one without knowing which.
   */
  private recordSeed(event: Json): number {
    const runId = str(event.run_id);
    const messages = Array.isArray(event.messages) ? (event.messages as unknown[]) : [];
    const digest = str(event.digest);

    if (!this.seeded) {
      this.seeded = true;
      // THE PREFIX CHAIN THE CHILD REPORTED, one digest per message, and the host copies it
      // rather than computing it. A seed says ONE digest for N messages and the fold checks
      // `digest_after` at every entry, so somebody has to produce N; the AILANG twin recomputes
      // them with `journal.chain_digest_after`, and doing that HERE would mean a second copy of
      // `phase_vocab.canonical_message_frame` in TypeScript — across a language boundary neither
      // compiler can see, drifting silently the first time the message form changes, and writing
      // journals that fold today and refuse tomorrow. So the child reports the chain it already
      // folded (`HistorySeededInfo.digests`, P3 Part 4), and the host computes no digest at all.
      const digests = Array.isArray(event.digests) ? (event.digests as unknown[]) : [];
      if (digests.length !== messages.length) {
        // FAIL CLOSED, and say so. A seed whose chain does not match its messages cannot be
        // expanded into entries the fold will accept, and writing a partial expansion would leave
        // a journal that refuses at its first history entry with no record of why.
        this.unresumableReason =
          `history_seeded carried ${digests.length} digest(s) for ${messages.length} message(s); ` +
          `the seed cannot be expanded and the session is not resumable`;
        this.onError(this.unresumableReason);
        return 0;
      }
      let written = 0;
      for (let i = 0; i < messages.length; i += 1) {
        const next = str(digests[i]);
        if (
          this.append("history_appended", {
            run_id: runId,
            step: 0,
            message: messages[i],
            replaces_previous: false,
            digest_after: next,
          })
        ) {
          this.chainDigest = next;
          this.noteHistoryMessage(messages[i]);
          written += 1;
        }
      }
      // `digest` is `digests`' last element by construction, so this is a no-op on a well-formed
      // seed — and on a seed with no messages at all it is the only thing that sets the chain.
      if (digest !== "") this.chainDigest = digest;
      this.replacedSinceSeed = false;
      return written;
    }

    if (this.replaceNextSeed) {
      this.replaceNextSeed = false;
      const ok = this.append("history_replaced", {
        run_id: runId,
        step: 0,
        reason: "profile_switch",
        messages,
        digest_after: digest,
      });
      if (ok) {
        this.chainDigest = digest;
        this.historyMessages = messages.length;
        this.openCallIds = [];
        this.replacedSinceSeed = false;
      }
      return ok ? 1 : 0;
    }

    if (digest !== this.chainDigest) {
      // THE HOST IS THE FIRST PLACE THIS CAN BE SEEN, and P3 Part 3 named the case it will
      // usually be. The conversation loop's `HistoryAppended` recomputes `digest_after` from the
      // turn's history because `Continuation` and `FinalState` carry no chain field, so the run's
      // chain dies with the run — which is right for every session whose journal holds no
      // `history_replaced`, and wrong after a checkpoint has re-based the chain. Only the host
      // holds both values at once, so only the host can say WHICH failure this is instead of
      // leaving an operator with a fold that refuses at some entry.
      const known = this.replacedSinceSeed
        ? " — a history_replaced has been journaled since the last seed, so this is the" +
          " conversation loop's known chain limitation (P3 Part 3 §4), not a corrupted journal"
        : "";
      this.unresumableReason =
        `history_seeded digest ${digest || "(empty)"} does not match the last history entry's ` +
        `digest_after ${this.chainDigest || "(empty)"}; the child's history and the journal's have diverged${known}`;
      this.onError(this.unresumableReason);
    }
    return 0;
  }

  private recordAppended(event: Json): number {
    const message = event.message;
    const replaces = event.replaces_previous === true;
    const digestAfter = str(event.digest_after);
    const ok = this.append("history_appended", {
      run_id: str(event.run_id),
      step: num(event.step),
      message,
      replaces_previous: replaces,
      digest_after: digestAfter,
    });
    if (!ok) return 0;
    this.chainDigest = digestAfter;
    if (replaces) {
      // The hybrid batch's first entry SUPERSEDES the message the previous entry holds, so the
      // count does not grow — the fold drops that message when it reads the flag. Counting it
      // would put `first_kept` one past where the fold is.
      this.replaceLastHistoryMessage(message);
    } else {
      this.noteHistoryMessage(message);
    }
    return 1;
  }

  private recordReplaced(event: Json): number {
    const messages = Array.isArray(event.messages) ? (event.messages as unknown[]) : [];
    const digestAfter = str(event.digest_after);
    const payload: Json = {
      run_id: str(event.run_id),
      step: num(event.step),
      reason: str(event.reason, "checkpoint"),
      messages,
      digest_after: digestAfter,
    };
    // `first_kept` is an index into the PRE-replacement history, so it is bounded by the count the
    // journal has been keeping. Out of range means the host and the child disagree about the
    // history's length, and an entry written anyway would fold to a silent truncation — the fold
    // reads the index and cannot tell a wrong one from a deliberate one.
    if (typeof event.first_kept === "number" && Number.isInteger(event.first_kept)) {
      const k = event.first_kept as number;
      if (k >= 0 && k <= this.historyMessages) {
        payload.first_kept = k;
      } else {
        this.onError(
          `history_replaced first_kept ${k} is outside the journal's ${this.historyMessages} history messages; dropped`,
        );
      }
    }
    const ok = this.append("history_replaced", payload);
    if (!ok) return 0;
    this.chainDigest = digestAfter;
    // The fold rebuilds the history as the head system prefix, then this entry's messages, then
    // whatever follows — so the count after a replacement is the head prefix the host does not
    // see plus these. `first_kept` is only ever compared against the count BEFORE the next
    // replacement, and a checkpoint that keeps no tail is the HEAD behaviour, so tracking these is
    // the closest honest value and errs toward refusing rather than accepting.
    this.historyMessages = messages.length;
    this.openCallIds = [];
    this.replacedSinceSeed = true;
    return 1;
  }

  private recordStateDelta(event: Json): number {
    const payload: Json = {
      run_id: str(event.run_id),
      step: num(event.step),
      cumulative: obj(event.cumulative) ?? {},
      telemetry: obj(event.telemetry) ?? {},
      ext_artifacts_digest: str(event.ext_artifacts_digest),
    };
    // Inline only when the child inlined it — D1 sends the artifacts only when the digest changed,
    // and a host that re-sent the last known value would turn "unchanged" into "changed again".
    if (event.ext_artifacts !== undefined) payload.ext_artifacts = event.ext_artifacts;
    return this.append("state_delta", payload) ? 1 : 0;
  }

  private recordRunFinished(event: Json): number {
    return this.append("run_finished", {
      run_id: str(event.run_id, this.lastRunId),
      cumulative: obj(event.cumulative) ?? {},
      // PLAN-001 P2 has not landed `ordinal` on the world, so there is nothing to carry and D5's
      // `from_ordinal` rule waits for it. `journal.ail` decodes the field strictly and ignores the
      // value, which is what makes writing 0 now safe and the schema stable across that landing.
      world_ordinal: num(event.world_ordinal),
      finish_reason: str(event.finish_reason),
    })
      ? 1
      : 0;
  }

  /**
   * A resume that switched profile is TWO entries, and D5 says why: the `resumed` entry records
   * both sides of every comparison the host made, and the accepted switch is SEPARATELY a
   * `settings` entry, because `settings` is where the fold reads `profile` from (rule 5).
   */
  private recordResumed(event: Json): number {
    const from = str(event.prompt_digest_from);
    const to = str(event.prompt_digest_to);
    const profileFrom = str(event.profile_from);
    const profileTo = str(event.profile_to);
    const ok = this.append("resumed", {
      resume_count: num(event.resume_count),
      from_id: str(event.from_id),
      from_ordinal: num(event.from_ordinal),
      profile_from: profileFrom,
      profile_to: profileTo,
      prompt_digest_from: from,
      prompt_digest_to: to,
      forced: event.forced === true,
    });
    if (!ok) return 0;
    // D1's second arm arms itself HERE, from the entry just written, rather than from a flag the
    // resumer sets by hand: the condition is a property of the `resumed` entry and reading it off
    // the entry is what keeps the two in step.
    this.replaceNextSeed = from !== to;
    let n = 1;
    if (profileTo !== "" && profileTo !== profileFrom) {
      if (this.append("settings", { profile: profileTo })) n += 1;
    }
    return n;
  }

  // --------------------------------------------------------------------------
  // The exit entry.
  // --------------------------------------------------------------------------

  /**
   * D1's `exit`, the one entry whose producer is the HOST. `abort` and `restart` are the same
   * entry with their reason, which is what replaced v4.1's two metadata rewrites.
   *
   * Safe to call from a `process.on("exit")` listener: `append` is `appendFileSync` and
   * `pending_tool_calls` is already in memory, so this does no asynchronous work and reads no
   * file.
   *
   * MORE THAN ONE PER SESSION IS CORRECT — a `/restart` writes `exit(restart)` and the respawn
   * carries on in the same journal, so the boundary is a real one and the entries after it are
   * real too. What is suppressed is a CONSECUTIVE second exit: on a normal quit the child-exit
   * callback and the process hook both fire with nothing between them, and two boundaries in a row
   * would tell a reader the session ended twice. The fold takes `last` from the final entry, so
   * the distinction is not cosmetic.
   */
  private lastEntryWasExit = false;

  writeExit(reason: string): boolean {
    if (this.lastEntryWasExit) return false;
    if (this.seq === 0) return false;
    const id = this.append("exit", {
      reason,
      pending_tool_calls: this.openCallIds.slice(),
    });
    if (id !== null) this.lastEntryWasExit = true;
    return id !== null;
  }

  /** The trailing-pair rule, as D1 states it, over what the host holds. Exposed for the test. */
  get pendingToolCalls(): string[] {
    return this.openCallIds.slice();
  }

  // --------------------------------------------------------------------------
  // The chain, the history count and the trailing-pair rule.
  // --------------------------------------------------------------------------

  /**
   * The last history entry's `digest_after`, held so D1's third arm has something to compare the
   * next seed against. It is never RECOMPUTED from a message — except across the seed expansion,
   * where the event gives one digest for N entries and there is no child value to carry.
   */
  private chainDigest = "";

  private lastRunId = "";

  private noteHistoryMessage(message: unknown): void {
    this.historyMessages += 1;
    this.updatePending(message);
  }

  private replaceLastHistoryMessage(message: unknown): void {
    if (this.historyMessages === 0) this.historyMessages = 1;
    this.updatePending(message);
  }

  /**
   * THE TRAILING-PAIR RULE, three lines as D1 promised: an assistant's `tool_calls` become the
   * open set; a tool result closes the id it answers; anything else leaves the set alone. What is
   * still open when the session exits is what `kill -9` caught mid tool-phase, and it is what the
   * fold will strip on the resume that follows.
   */
  private updatePending(message: unknown): void {
    const m = obj(message);
    if (!m) return;
    const calls = Array.isArray(m.tool_calls) ? (m.tool_calls as unknown[]) : [];
    if (calls.length > 0) {
      this.openCallIds = calls.map((c) => str(obj(c)?.id)).filter((id) => id !== "");
      return;
    }
    const answered = str(m.tool_call_id);
    if (answered !== "") this.openCallIds = this.openCallIds.filter((id) => id !== answered);
  }

  /** Track the run id so `run_finished` can carry one: `run_summary` has no `run_id` field. */
  noteRunId(runId: string): void {
    if (runId !== "") this.lastRunId = runId;
  }
}

/**
 * THE JSONL LOG'S DIGEST SUBSTITUTION — D3, and it lands with the routing or the log doubles.
 *
 * `parseAgentEventLine` accepts any object with a string `type` and `SessionLogger` writes unknown
 * types verbatim (`runtime-process.unknown-events.test.ts` pins that), so from the moment P3 Part 3
 * put `history_seeded` on the wire the JSONL log has been carrying the whole conversation a second
 * time. Measured at P3 Part 3: 87% of the wire's bytes are `history_seeded`, ~200 KB per turn at
 * a long history, because every turn re-sends the whole conversation. The journal is where that
 * content belongs; the log keeps carrying digests, exactly as it did before these events existed.
 *
 * WHAT SURVIVES SUBSTITUTION is everything a log reader used the line for: the type, the run id,
 * the step, the chain digest, the message count, and — for `state_delta` — the artifacts digest,
 * which was already a sibling of the artifacts. `journaled: true` says where the content went, so
 * a reader is told rather than left to conclude the payload was lost.
 */
export function substituteJournalPayload(event: Json): Json {
  const type = str(event.type);
  switch (type) {
    case "history_seeded": {
      const messages = Array.isArray(event.messages) ? (event.messages as unknown[]) : [];
      // `digests` goes too, and it is not a rounding error: it is one 71-byte digest per message,
      // re-sent on every turn's seed, so a hundred-message history pays ~7 KB a turn for a list
      // whose every element is already in the journal as an entry's `digest_after`. `digest` — the
      // last of them, and the one D1's third arm compares — stays, because that one is what a log
      // reader needs to line a turn up against the journal.
      const { messages: _m, digests: _d, ...rest } = event;
      return { ...rest, messages_digest: payloadDigest(messages), messages_count: messages.length, journaled: true };
    }
    case "history_appended": {
      const { message: _m, ...rest } = event;
      return { ...rest, message_digest: payloadDigest(event.message), journaled: true };
    }
    case "history_replaced": {
      const messages = Array.isArray(event.messages) ? (event.messages as unknown[]) : [];
      const { messages: _m, ...rest } = event;
      return { ...rest, messages_digest: payloadDigest(messages), messages_count: messages.length, journaled: true };
    }
    case "state_delta": {
      // `ext_artifacts` is the only bulk field, and its digest is ALREADY a sibling written by the
      // child — so this drops the value and adds nothing. `run_summary`, `session_start`,
      // `run_suspended`, `session_resumed` and `model_change` carry no bulk payload at all and are
      // logged unchanged: substituting them would cost a log reader real information for no bytes.
      if (event.ext_artifacts === undefined) return event;
      const { ext_artifacts: _a, ...rest } = event;
      return { ...rest, journaled: true };
    }
    default:
      return event;
  }
}
