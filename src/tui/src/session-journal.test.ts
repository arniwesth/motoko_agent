import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import {
  SessionJournal,
  isJournalClass,
  substituteJournalPayload,
  entryId,
  emptyBoot,
} from "./session-journal.js";
import { SessionLogger } from "./session-logger.js";

// ADR-003 v6.1 D1's entries and D3's one writer, host side.
//
// What these assert is the three things the fold cannot check for itself, because the fold reads a
// FILE and by then every one of these decisions has already been taken: that `history_seeded` is
// resolved into the right SHAPE of entries (D1's three arms differ by count, not by content), that
// the header's one in-place rewrite is atomic and happens once, and that the JSONL log stops
// carrying the payloads the journal now holds. The fold's own rules are `journal.ail`'s tests, and
// a live journal being accepted by `fold_journal` is this part's gate.

let root: string;

beforeEach(() => {
  root = fs.mkdtempSync(path.join(os.tmpdir(), "motoko-journal-"));
});

afterEach(() => {
  fs.rmSync(root, { recursive: true, force: true });
});

function open(sessionId = "sess-1"): SessionJournal {
  const j = new SessionJournal(root, sessionId, { now: () => 1756000000000, onError: () => {} });
  j.writeHeader({ sessionId, workdir: "/w", profile: "p", model: "m" });
  return j;
}

function lines(j: SessionJournal): Array<Record<string, unknown>> {
  return fs
    .readFileSync(j.filePath, "utf8")
    .split("\n")
    .filter((l) => l.trim() !== "")
    .map((l) => JSON.parse(l) as Record<string, unknown>);
}

function msg(role: string, content: string, extra: Record<string, unknown> = {}): Record<string, unknown> {
  return { role, content, tool_calls: [], tool_call_id: "", images: [], ...extra };
}

describe("the journal file", () => {
  it("lives at .motoko/sessions/<session_id>/journal.jsonl and its directory is 0700", () => {
    const j = open("sess-mode");
    expect(j.filePath).toBe(path.join(root, ".motoko", "sessions", "sess-mode", "journal.jsonl"));
    // The journal carries the conversation verbatim — every prompt, every tool output, every file
    // the model read. The log directory beside it carries digests, which is why this one is the
    // mode that had to be said out loud.
    expect(fs.statSync(j.dir).mode & 0o777).toBe(0o700);
  });

  // D1's envelope. `id` is host-assigned and opaque to the child; `parent_id` is the leaf at the
  // time of the append and null on the root; `seq` is the file position. The fold walks `parent_id`
  // from the leaf, so a broken chain folds a prefix of the session and says nothing about it.
  it("gives every entry the envelope the fold walks, with the header as the root", () => {
    const j = open();
    j.record({ type: "session_start", run_id: "sess-1.r0.0" });
    j.record({ type: "run_summary", finish_reason: "stop", cumulative: {} });
    const written = lines(j);
    expect(written.map((l) => l.type)).toEqual(["header", "run_started", "run_finished"]);
    expect(written.map((l) => l.id)).toEqual(["0000", "0001", "0002"]);
    expect(written.map((l) => l.parent_id)).toEqual([null, "0000", "0001"]);
    expect(written.map((l) => l.seq)).toEqual([0, 1, 2]);
    expect(j.currentLeaf).toBe("0002");
  });

  // Byte-identical to `journal.ail`'s `entry_id`, because the twin and this writer produce files
  // that the same fold reads and the same operator greps.
  it("pads the entry id exactly as the AILANG twin does", () => {
    expect([entryId(0), entryId(9), entryId(10), entryId(99), entryId(100), entryId(999), entryId(1000)]).toEqual([
      "0000", "0009", "0010", "0099", "0100", "0999", "1000",
    ]);
  });

  // `run_summary` has no `run_id` — it is the run's summary and the run is the frame it is in — so
  // the entry takes the id `session_start` named, exactly as the twin does.
  it("carries the run id from run_started onto run_finished", () => {
    const j = open();
    j.record({ type: "session_start", run_id: "sess-1.r0.7" });
    j.record({ type: "run_summary", finish_reason: "stop", cumulative: {} });
    expect(lines(j)[2].run_id).toBe("sess-1.r0.7");
  });
});

describe("the header, and its one in-place rewrite", () => {
  // A header written from the host's values alone is COMPLETE AS JSON and empty as a contract: the
  // digests are "" and `boot` is zeroed. That is not a half-written file — `journal.ail`'s
  // `boot_of_json` is strict per field, and a header missing keys would be refused as MALFORMED,
  // which is a different thing to tell an operator than "the child never reported".
  it("is decodable from the first byte, with the child's fields honestly empty", () => {
    const j = open();
    const h = lines(j)[0];
    expect(h.type).toBe("header");
    expect(h.schema_version).toBe(1);
    expect(h.session_id).toBe("sess-1");
    expect(h.workdir).toBe("/w");
    expect(h.profile).toBe("p");
    expect(h.model).toBe("m");
    expect(h.system_prefix_digest).toBe("");
    expect(h.ext_set_digest).toBe("");
    expect(h.boot).toMatchObject({ task: "", step_budget: 0, ohmy_pi: false });
  });

  it("is completed in place, without disturbing the entries after it", () => {
    const j = open();
    j.record({ type: "session_start", run_id: "r0" });
    expect(
      j.completeHeader({
        system_prefix_digest: "sha256:sys",
        ext_set_digest: "sha256:ext",
        boot: { ...(lines(j)[0].boot as Record<string, unknown>), task: "do the thing", step_budget: 8 },
      }),
    ).toBe(true);
    const written = lines(j);
    expect(written).toHaveLength(2);
    expect(written[0].system_prefix_digest).toBe("sha256:sys");
    expect(written[0].ext_set_digest).toBe("sha256:ext");
    expect((written[0].boot as Record<string, unknown>).task).toBe("do the thing");
    // The envelope of the header is untouched, and so is everything after it.
    expect(written[0].id).toBe("0000");
    expect(written[1]).toMatchObject({ type: "run_started", id: "0001", parent_id: "0000" });
  });

  // ONCE. A second rewrite is a second window in which a `kill -9` could catch the copy, and a
  // respawn emits its own startup report — so the second one is refused rather than performed.
  it("refuses a second completion", () => {
    const j = open();
    const boot = lines(j)[0].boot as Record<string, unknown>;
    expect(j.completeHeader({ system_prefix_digest: "a", ext_set_digest: "b", boot })).toBe(true);
    expect(j.completeHeader({ system_prefix_digest: "z", ext_set_digest: "z", boot })).toBe(false);
    expect(lines(j)[0].system_prefix_digest).toBe("a");
  });

  // Atomic via rename (D3). Asserted through the consequence rather than the syscall: no temporary
  // file survives the publish, so no reader can ever be handed one.
  it("leaves no temporary file behind", () => {
    const j = open();
    j.completeHeader({ system_prefix_digest: "a", ext_set_digest: "b", boot: lines(j)[0].boot as Record<string, unknown> });
    expect(fs.readdirSync(j.dir).filter((f) => f.endsWith(".tmp"))).toEqual([]);
  });

  // A journal whose child died before it could report has a header and NO HISTORY, and the fold
  // refuses it through the history rules — there is no completeness flag in the format and D3 does
  // not ask for one. The host side of that claim is only this: the file exists, the header is
  // there, and nothing pretends it was completed.
  it("reports a never-completed header as never completed", () => {
    const j = open();
    expect(j.isHeaderCompleted).toBe(false);
    expect(lines(j)).toHaveLength(1);
  });
});

describe("history_seeded: D1's three arms", () => {
  // ARM 1. The session's first seed IS the history, so it becomes N `history_appended` entries,
  // one message each — which is what makes `first_kept` a lookup and what lets the fold check a
  // chain at every step.
  it("expands the session's first seed into one entry per message", () => {
    const j = open();
    j.record({
      type: "history_seeded",
      run_id: "r0",
      messages: [msg("system", "s"), msg("user", "t")],
      digest: "sha256:seed-2",
      digests: ["sha256:seed-1", "sha256:seed-2"],
    });
    const written = lines(j).slice(1);
    expect(written.map((l) => l.type)).toEqual(["history_appended", "history_appended"]);
    expect(written.map((l) => (l.message as Record<string, unknown>).role)).toEqual(["system", "user"]);
    expect(written.every((l) => l.replaces_previous === false)).toBe(true);
    // THE CHILD'S DIGESTS, COPIED. The host computes none: `journal.chain_digest_after` is AILANG
    // over `phase_vocab.canonical_message_frame`, and a TypeScript reconstruction would be a
    // second copy of that canonicalisation across a boundary neither compiler can see. It would
    // also be UNDETECTABLE here and fatal in the fold, which recomputes the chain at every entry —
    // the first live journal this part produced was refused at exactly this entry for exactly that
    // reason, which is why the seed now carries its prefix chain.
    expect(written.map((l) => l.digest_after)).toEqual(["sha256:seed-1", "sha256:seed-2"]);
  });

  // FAIL CLOSED. A seed whose chain does not match its messages cannot be expanded into entries
  // the fold will accept, and a partial expansion would leave a journal that refuses at its first
  // history entry with no record of why.
  it("refuses to expand a seed whose digests do not match its messages", () => {
    const j = open();
    expect(
      j.record({
        type: "history_seeded",
        run_id: "r0",
        messages: [msg("system", "s"), msg("user", "t")],
        digest: "sha256:seed",
        digests: ["sha256:only-one"],
      }),
    ).toBe(0);
    expect(lines(j)).toHaveLength(1);
    expect(j.unresumable).toContain("1 digest(s) for 2 message(s)");
  });

  // ARM 3. A follow-up turn re-states a history the journal already holds, so the host COMPARES the
  // seed's digest with the last history entry's `digest_after` — both child-computed, the host
  // computes none — and DROPS the event. Duplicating it would double the history on every turn.
  it("drops a later seed whose digest matches the chain", () => {
    const j = open();
    j.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s")], digest: "sha256:seed", digests: ["sha256:seed"] });
    const before = lines(j).length;
    expect(j.record({ type: "history_seeded", run_id: "r1", messages: [msg("system", "s")], digest: "sha256:seed", digests: ["sha256:seed"] })).toBe(0);
    expect(lines(j)).toHaveLength(before);
    expect(j.unresumable).toBeNull();
  });

  // ARM 3, the other side. A mismatch means the child's history and the journal's have diverged,
  // and appending either would be choosing one without knowing which. The session is marked
  // unresumable and the event is still dropped — THE HOST IS THE ONLY PLACE THAT HOLDS BOTH VALUES
  // AT ONCE, which is why it and not the fold is where this is caught.
  it("marks the session unresumable when a later seed's digest disagrees", () => {
    const j = open();
    j.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s")], digest: "sha256:seed", digests: ["sha256:seed"] });
    expect(j.record({ type: "history_seeded", run_id: "r1", messages: [msg("system", "s")], digest: "sha256:other", digests: ["sha256:other"] })).toBe(0);
    expect(j.unresumable).toContain("diverged");
    expect(j.unresumable).toContain("sha256:other");
  });

  // P3 Part 3's stated limitation, and the host naming it. The conversation loop recomputes
  // `digest_after` from the turn's history because the run's chain dies with the run, which is
  // right until a checkpoint re-bases the chain. Only the host can tell that case from a corrupted
  // journal, so it says which one it is instead of leaving an operator with a fold that refuses.
  it("names the conversation loop's chain limitation when a replacement preceded the mismatch", () => {
    const j = open();
    j.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s")], digest: "sha256:seed", digests: ["sha256:seed"] });
    j.record({
      type: "history_replaced",
      run_id: "r0",
      step: 3,
      reason: "checkpoint",
      messages: [msg("assistant", "summary")],
      digest_after: "sha256:rebased",
    });
    j.record({ type: "history_seeded", run_id: "r1", messages: [msg("system", "s")], digest: "sha256:stale", digests: ["sha256:stale"] });
    expect(j.unresumable).toContain("known chain limitation");
  });

  // ARM 2. After a resume that changed the prompt digest — a profile switch replaced the whole head
  // prefix — the seed is a NEW head and becomes a `history_replaced`, which re-bases the chain. The
  // flag is read off the `resumed` entry the host just wrote, not set by hand, so the two cannot
  // drift apart.
  it("journals the seed after a prompt-digest change as a history_replaced", () => {
    const j = open();
    j.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "old")], digest: "sha256:seed", digests: ["sha256:seed"] });
    j.record({
      type: "session_resumed",
      resume_count: 1,
      from_id: "0001",
      from_ordinal: 0,
      profile_from: "p",
      profile_to: "q",
      prompt_digest_from: "sha256:a",
      prompt_digest_to: "sha256:b",
      forced: false,
    });
    expect(j.record({ type: "history_seeded", run_id: "r1", messages: [msg("system", "new")], digest: "sha256:new", digests: ["sha256:new"] })).toBe(1);
    const last = lines(j).pop()!;
    expect(last.type).toBe("history_replaced");
    expect(last.reason).toBe("profile_switch");
    expect(last.digest_after).toBe("sha256:new");
  });

  // ...and only for ONE seed. `replaceNextSeed` describes the seed that follows the resume, not a
  // mode: the turn after it is an ordinary follow-up and must go back to compare-and-drop.
  it("arms the replacement for exactly one seed", () => {
    const j = open();
    j.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "old")], digest: "sha256:seed", digests: ["sha256:seed"] });
    j.record({
      type: "session_resumed",
      resume_count: 1, from_id: "0001", from_ordinal: 0,
      profile_from: "p", profile_to: "q",
      prompt_digest_from: "sha256:a", prompt_digest_to: "sha256:b", forced: false,
    });
    j.record({ type: "history_seeded", run_id: "r1", messages: [msg("system", "new")], digest: "sha256:new", digests: ["sha256:new"] });
    expect(j.record({ type: "history_seeded", run_id: "r1", messages: [msg("system", "new")], digest: "sha256:new", digests: ["sha256:new"] })).toBe(0);
  });

  // A resume that switched profile is TWO entries: the `resumed` entry records both sides of every
  // comparison the host made, and the accepted switch is SEPARATELY a `settings` entry, because
  // `settings` is where the fold reads `profile` from (D4 rule 5).
  it("writes a settings entry beside a resumed entry that switched profile", () => {
    const j = open();
    expect(
      j.record({
        type: "session_resumed",
        resume_count: 1, from_id: "0000", from_ordinal: 0,
        profile_from: "p", profile_to: "q",
        prompt_digest_from: "sha256:a", prompt_digest_to: "sha256:a", forced: false,
      }),
    ).toBe(2);
    expect(lines(j).map((l) => l.type)).toEqual(["header", "resumed", "settings"]);
    expect(lines(j)[2].profile).toBe("q");
  });
});

describe("the other journal-class events", () => {
  it("passes a history_appended through with the child's digest untouched", () => {
    const j = open();
    j.record({
      type: "history_appended",
      run_id: "r0", step: 2,
      message: msg("assistant", "hi"),
      replaces_previous: true,
      digest_after: "sha256:child",
    });
    const e = lines(j)[1];
    expect(e).toMatchObject({ type: "history_appended", run_id: "r0", step: 2, replaces_previous: true, digest_after: "sha256:child" });
  });

  // The artifacts are inlined ONLY when the child inlined them: D1 sends them only when the digest
  // changed, and a host that re-sent the last known value would turn "unchanged" into "changed".
  it("inlines ext_artifacts on a state_delta only when the child did", () => {
    const j = open();
    j.record({ type: "state_delta", run_id: "r0", step: 1, cumulative: {}, telemetry: {}, ext_artifacts_digest: "sha256:e" });
    j.record({ type: "state_delta", run_id: "r0", step: 2, cumulative: {}, telemetry: {}, ext_artifacts_digest: "sha256:f", ext_artifacts: { compose: "v1" } });
    const written = lines(j).slice(1);
    expect("ext_artifacts" in written[0]).toBe(false);
    expect(written[1].ext_artifacts).toEqual({ compose: "v1" });
  });

  // `first_kept` is an index into the PRE-replacement history, so it is bounded by the count the
  // journal has been keeping. Out of range means the host and the child disagree about the
  // history's length, and an entry written anyway would fold to a SILENT TRUNCATION — the fold
  // reads the index and cannot tell a wrong one from a deliberate one.
  it("drops a first_kept that is outside the history it has journaled", () => {
    const j = open();
    j.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s"), msg("user", "t")], digest: "sha256:b", digests: ["sha256:a", "sha256:b"] });
    j.record({ type: "history_replaced", run_id: "r0", step: 1, reason: "checkpoint", first_kept: 2, messages: [msg("assistant", "sum")], digest_after: "sha256:r" });
    expect(lines(j).pop()!.first_kept).toBe(2);

    const k = open("sess-2");
    k.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s")], digest: "sha256:seed", digests: ["sha256:seed"] });
    k.record({ type: "history_replaced", run_id: "r0", step: 1, reason: "checkpoint", first_kept: 9, messages: [msg("assistant", "sum")], digest_after: "sha256:r" });
    expect("first_kept" in lines(k).pop()!).toBe(false);
  });

  // `model_change` is the one journal-class event the CHILD never emits — it is a host-to-child
  // command. The host writes the entry because the host is the only side that knows, and it is the
  // entry the fold reads `model` from.
  it("journals a model change as a settings entry", () => {
    const j = open();
    expect(j.record({ type: "model_change", model: "claude-opus-5" })).toBe(1);
    expect(lines(j).pop()).toMatchObject({ type: "settings", model: "claude-opus-5" });
  });

  // ADR-003 D7 row 6: the wake is the park's CHILD, and it is because D1's `parent_id` is the leaf
  // and nothing is appended between them — no branch operation exists. `waits` is copied as the
  // child sent it; the fold decodes each element through `wait_descriptor_from_json`.
  it("journals a park and its wake, the wake as the park's child", () => {
    const j = open();
    j.record({ type: "session_start", run_id: "r0" });
    const waits = [
      { id: "h1", delegate_kind: "codex", locator: { pane: "%3" }, answer_path: "/w/a.md", run_key: "k1" },
      { id: "op" },
    ];
    expect(j.record({ type: "park_entered", request_id: "r0.p0", step: 2, waits })).toBe(1);
    expect(j.record({ type: "wake_received", request_id: "r0.p0", wait_id: "h1", outcome: "settled", detail: "answer" })).toBe(1);
    const all = lines(j);
    expect(all.map((l) => l.type)).toEqual(["header", "run_started", "park", "wake"]);
    const [, , park, wake] = all;
    expect(park).toMatchObject({ request_id: "r0.p0", step: 2, waits });
    expect(wake.parent_id).toBe(park.id);
    expect(wake).toMatchObject({ request_id: "r0.p0", wait_id: "h1", outcome: "settled", detail: "answer" });
  });

  it("ignores an event that is not journal-class", () => {
    const j = open();
    expect(j.record({ type: "thinking_delta", step: 1, text_delta: "x" })).toBe(0);
    expect(lines(j)).toHaveLength(1);
  });
});

describe("the exit entry and its trailing-pair rule", () => {
  // D1's three-line twin of the fold's dangling rule: the last assistant's `tool_calls` minus the
  // `tool_call_id`s of the entries after it. What is still open at exit is what a crash caught mid
  // tool-phase, and it is what the resume that follows will strip.
  it("records the tool calls no result answered", () => {
    const j = open();
    j.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s")], digest: "sha256:seed", digests: ["sha256:seed"] });
    j.record({
      type: "history_appended", run_id: "r0", step: 1, replaces_previous: false, digest_after: "d1",
      message: msg("assistant", "", { tool_calls: [{ id: "c1" }, { id: "c2" }] }),
    });
    j.record({
      type: "history_appended", run_id: "r0", step: 1, replaces_previous: false, digest_after: "d2",
      message: msg("tool", "out", { tool_call_id: "c1" }),
    });
    expect(j.pendingToolCalls).toEqual(["c2"]);
    expect(j.writeExit("child_exit")).toBe(true);
    expect(lines(j).pop()).toMatchObject({ type: "exit", reason: "child_exit", pending_tool_calls: ["c2"] });
  });

  it("records an empty list when every call was answered", () => {
    const j = open();
    j.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s")], digest: "sha256:seed", digests: ["sha256:seed"] });
    j.record({
      type: "history_appended", run_id: "r0", step: 1, replaces_previous: false, digest_after: "d1",
      message: msg("assistant", "", { tool_calls: [{ id: "c1" }] }),
    });
    j.record({
      type: "history_appended", run_id: "r0", step: 1, replaces_previous: false, digest_after: "d2",
      message: msg("tool", "out", { tool_call_id: "c1" }),
    });
    j.writeExit("host_exit");
    expect(lines(j).pop()!.pending_tool_calls).toEqual([]);
  });

  // MORE THAN ONE PER SESSION IS CORRECT: a `/restart` writes `exit(restart)` and the respawn
  // carries on in the same journal. What is suppressed is a CONSECUTIVE second exit — on a normal
  // quit the child-exit callback and the process hook both fire with nothing between them, and two
  // boundaries in a row would tell a reader the session ended twice. The fold takes `last` from the
  // final entry, so the distinction is not cosmetic.
  it("suppresses a consecutive exit but allows one after a restart", () => {
    const j = open();
    j.record({ type: "session_start", run_id: "r0" });
    expect(j.writeExit("restart")).toBe(true);
    expect(j.writeExit("host_exit")).toBe(false);
    j.record({ type: "session_start", run_id: "r1" });
    expect(j.writeExit("host_exit")).toBe(true);
    expect(lines(j).map((l) => l.type)).toEqual(["header", "run_started", "exit", "run_started", "exit"]);
  });

  // The exit hook runs in a `process.on("exit")` listener with no event loop left, so the append
  // has to have REACHED THE FILE by the time the call returns. Asserted by reading the file back
  // synchronously with no await anywhere between.
  it("has reached the file by the time writeExit returns", () => {
    const j = open();
    j.record({ type: "session_start", run_id: "r0" });
    j.writeExit("host_exit");
    expect(fs.readFileSync(j.filePath, "utf8")).toContain('"type":"exit"');
  });

  it("writes no exit entry into a journal with no header", () => {
    const j = new SessionJournal(root, "sess-empty", { now: () => 1, onError: () => {} });
    expect(j.writeExit("host_exit")).toBe(false);
    expect(fs.existsSync(j.filePath)).toBe(false);
  });
});

describe("the JSONL log's digest substitution", () => {
  // D3: the journal carries content and the log keeps carrying digests. Without this the log has
  // been carrying the whole conversation a SECOND time since P3 Part 3 put these events on the
  // wire — `parseAgentEventLine` accepts any object with a string `type` and the logger wrote
  // unknown types verbatim. Measured there: 87% of the wire's bytes.
  it("replaces the bulk payload of every history event with a digest", () => {
    const seeded = substituteJournalPayload({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s"), msg("user", "t")], digest: "sha256:b", digests: ["sha256:a", "sha256:b"] });
    expect("messages" in seeded).toBe(false);
    // The prefix chain goes with the messages: one 71-byte digest per message, re-sent on every
    // turn's seed, and every element of it is already in the journal as an entry's `digest_after`.
    // `digest` — the last of them, and the one D1's third arm compares — stays.
    expect("digests" in seeded).toBe(false);
    expect(seeded.messages_count).toBe(2);
    expect(String(seeded.messages_digest)).toMatch(/^sha256:[0-9a-f]{64}$/);
    expect(seeded).toMatchObject({ run_id: "r0", digest: "sha256:b", journaled: true });

    const appended = substituteJournalPayload({ type: "history_appended", run_id: "r0", step: 1, message: msg("assistant", "hi"), replaces_previous: false, digest_after: "sha256:a" });
    expect("message" in appended).toBe(false);
    expect(appended).toMatchObject({ step: 1, digest_after: "sha256:a", journaled: true });

    const replaced = substituteJournalPayload({ type: "history_replaced", run_id: "r0", step: 3, reason: "checkpoint", messages: [msg("assistant", "sum")], digest_after: "sha256:r" });
    expect("messages" in replaced).toBe(false);
    expect(replaced.messages_count).toBe(1);
  });

  // `ext_artifacts` is the only bulk field a `state_delta` has, and its digest is ALREADY a sibling
  // the child wrote — so substitution drops the value and adds nothing of its own.
  it("drops a state_delta's inlined artifacts and keeps the digest the child sent", () => {
    const withArtifacts = substituteJournalPayload({ type: "state_delta", run_id: "r0", step: 1, cumulative: {}, telemetry: {}, ext_artifacts_digest: "sha256:e", ext_artifacts: { compose: "v1" } });
    expect("ext_artifacts" in withArtifacts).toBe(false);
    expect(withArtifacts.ext_artifacts_digest).toBe("sha256:e");
    const without = { type: "state_delta", run_id: "r0", step: 1, cumulative: {}, telemetry: {}, ext_artifacts_digest: "sha256:e" };
    expect(substituteJournalPayload(without)).toBe(without);
  });

  // The events with no bulk payload are logged UNCHANGED. Substituting them would cost a log reader
  // real information and save no bytes.
  it("leaves the payload-free journal-class events alone", () => {
    for (const e of [
      { type: "session_start", run_id: "r0", task: "t", model: "m" },
      { type: "run_summary", finish_reason: "stop" },
      { type: "run_suspended", session_id: "s", run_id: "r0", reason: "budget_exhausted", step: 3 },
      { type: "session_resumed", resume_count: 1 },
      { type: "model_change", model: "m" },
    ]) {
      expect(substituteJournalPayload(e)).toBe(e);
    }
  });

  it("knows exactly which events are journal-class", () => {
    // `park_entered` and `wake_received` are ADR-003 D7's, journal-class since PLAN-003 P4 Part 1:
    // both have been on the wire since PLAN-002 W4 (`phase_vocab.ail` declares the `LedgerEvent`s,
    // `runtime-process.ts` the host types), and `journal.ail` now has the `park` and `wake` entry
    // types that hold them — its fold refuses an unknown `type`, so listing them here and adding
    // the entry types are one change.
    for (const t of ["history_seeded", "history_appended", "history_replaced", "state_delta", "session_start", "run_summary", "model_change", "run_suspended", "session_resumed", "park_entered", "wake_received"]) {
      expect(isJournalClass(t)).toBe(true);
    }
    for (const t of ["thinking", "done", "error", "obs"]) {
      expect(isJournalClass(t)).toBe(false);
    }
  });
});

describe("SessionLogger routes to the journal and digests the log", () => {
  // The two halves land together or the log doubles — this is the assertion that says so: for one
  // run, the journal carries the messages and the JSONL carries a digest where they were.
  it("puts the messages in the journal and a digest in the JSONL", async () => {
    const saved = process.env.MOTOKO_SESSION_ID;
    process.env.MOTOKO_SESSION_ID = "routing-test";
    try {
      const j = open("routing-test");
      const logger = new SessionLogger(root, "test-tui", j);
      logger.log({ type: "history_seeded", run_id: "r0", messages: [msg("user", "the whole conversation")], digest: "sha256:seed", digests: ["sha256:seed"] } as never);
      await logger.close();

      const jsonl = fs.readFileSync(logger.filePath, "utf8");
      expect(jsonl).toContain('"messages_digest"');
      expect(jsonl).not.toContain("the whole conversation");
      expect(fs.readFileSync(j.filePath, "utf8")).toContain("the whole conversation");
    } finally {
      if (saved === undefined) delete process.env.MOTOKO_SESSION_ID;
      else process.env.MOTOKO_SESSION_ID = saved;
    }
  });

  // NO JOURNAL, NO SUBSTITUTION. Substitution MOVES content from the log to the journal, so a
  // logger with no journal to move it to would be deleting it. The eval harness and every
  // transcript test run that way and keep the behaviour they had before this part.
  it("leaves the payload in the JSONL when there is no journal to move it to", async () => {
    const saved = process.env.MOTOKO_SESSION_ID;
    process.env.MOTOKO_SESSION_ID = "no-journal-test";
    try {
      const logger = new SessionLogger(root, "test-tui");
      logger.log({ type: "history_seeded", run_id: "r0", messages: [msg("user", "the whole conversation")], digest: "sha256:seed", digests: ["sha256:seed"] } as never);
      await logger.close();
      expect(fs.readFileSync(logger.filePath, "utf8")).toContain("the whole conversation");
    } finally {
      if (saved === undefined) delete process.env.MOTOKO_SESSION_ID;
      else process.env.MOTOKO_SESSION_ID = saved;
    }
  });
});

describe("a second process on an existing journal", () => {
  // THE COUNTER AND THE LEAF ARE IN MEMORY (D1), which is right for a session and wrong for a
  // session's second PROCESS. After a `kill -9` the lease goes stale, the next Motoko on that
  // session id takes it over — that is the whole point of the stale-lease rule and the second
  // judging number depends on it — and a fresh counter would write `0000`, `0001`, … over an id
  // space the file already uses. The fold's path walk stops at the first REPEATED id, so the
  // result is not a corrupt file but a plausible one that folds a mangled path.
  //
  // MEASURED, not anticipated: the first `kill -9` run of this part's manual gate left a journal
  // with two entries at `seq: 0`, both headers.
  it("continues the sequence and the parent chain instead of restarting them", () => {
    const first = open("sess-crash");
    first.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s"), msg("user", "t")], digest: "sha256:b", digests: ["sha256:a", "sha256:b"] });

    // A new process: same directory, same file, nothing in memory.
    const second = new SessionJournal(root, "sess-crash", { now: () => 2, onError: () => {} });
    expect(second.entryCount).toBe(3);
    expect(second.currentLeaf).toBe("0002");
    second.record({ type: "session_start", run_id: "r1" });

    const written = lines(second);
    expect(written.map((l) => l.id)).toEqual(["0000", "0001", "0002", "0003"]);
    expect(written.map((l) => l.seq)).toEqual([0, 1, 2, 3]);
    expect(written.map((l) => l.parent_id)).toEqual([null, "0000", "0001", "0002"]);
    expect(written.filter((l) => l.type === "header")).toHaveLength(1);
  });

  it("writes no second header into a journal that has one", () => {
    open("sess-twice");
    const second = new SessionJournal(root, "sess-twice", { now: () => 2, onError: () => {} });
    second.writeHeader({ sessionId: "sess-twice", workdir: "/w", profile: "p", model: "m" });
    expect(lines(second).filter((l) => l.type === "header")).toHaveLength(1);
  });

  it("adopts a completed header as completed, and an incomplete one as incomplete", () => {
    const first = open("sess-hdr");
    expect(new SessionJournal(root, "sess-hdr", { onError: () => {} }).isHeaderCompleted).toBe(false);
    first.completeHeader({ system_prefix_digest: "sha256:sys", ext_set_digest: "sha256:ext", boot: emptyBoot() });
    expect(new SessionJournal(root, "sess-hdr", { onError: () => {} }).isHeaderCompleted).toBe(true);
  });

  // FAIL CLOSED WITHOUT `--resume`. A child that starts a fresh history states a seed digest that
  // does not continue the journal's chain; the seed is dropped and the session is marked
  // unresumable, rather than two chains being spliced into one file. Continuing the chain is what
  // `--resume` is for (P3 Part 5), where the child seeds from the FOLDED history and the digests
  // line up by construction — and the same adoption is what makes that comparison possible at all.
  it("carries the chain across the process boundary, so a fresh seed is caught", () => {
    const first = open("sess-chain");
    first.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s")], digest: "sha256:one", digests: ["sha256:one"] });

    const second = new SessionJournal(root, "sess-chain", { now: () => 2, onError: () => {} });
    expect(second.record({ type: "history_seeded", run_id: "r1", messages: [msg("system", "s")], digest: "sha256:one", digests: ["sha256:one"] })).toBe(0);
    expect(second.unresumable).toBeNull();

    const third = new SessionJournal(root, "sess-chain", { now: () => 3, onError: () => {} });
    expect(third.record({ type: "history_seeded", run_id: "r2", messages: [msg("system", "fresh")], digest: "sha256:different", digests: ["sha256:different"] })).toBe(0);
    expect(third.unresumable).toContain("diverged");
  });

  // A torn last line is what a crash mid-append leaves. Everything before it is sound, and the
  // next entry's `parent_id` names the last id that was whole.
  it("stops at a torn last line and parents the next entry on the last whole one", () => {
    const first = open("sess-torn");
    first.record({ type: "session_start", run_id: "r0" });
    fs.appendFileSync(first.filePath, '{"id":"0002","parent_id":"0001","seq":2,"type":"sta');

    const second = new SessionJournal(root, "sess-torn", { now: () => 2, onError: () => {} });
    expect(second.entryCount).toBe(2);
    expect(second.currentLeaf).toBe("0001");
  });
});

// PLAN-003 P3 Part 5's decisions on Part 4's open items, host side.
describe("resume bookkeeping", () => {
  // Open item 1: the startup banner is a `session_start` with no `run_id`, and it opens no run.
  it("journals no run_started for a session_start that names no run", () => {
    const j = open();
    expect(j.record({ type: "session_start", task: "", model: "m", brainVersion: "v", ailangBuilt: "b" })).toBe(0);
    expect(j.record({ type: "session_start", run_id: "sess-1.r0.0" })).toBe(1);
    expect(lines(j).map((l) => l.type)).toEqual(["header", "run_started"]);
  });

  // Open item 2: the unresumable reason survives the process that found it.
  it("persists an unresumable reason beside the journal and adopts it in a new process", () => {
    const j = open();
    j.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s")], digest: "sha256:seed", digests: ["sha256:seed"] });
    expect(j.canResume).toBe(true);
    j.record({ type: "history_seeded", run_id: "r1", messages: [msg("system", "s")], digest: "sha256:other", digests: ["sha256:other"] });
    expect(j.canResume).toBe(false);
    expect(fs.readFileSync(j.unresumablePath, "utf8")).toContain("does not match");
    const again = new SessionJournal(root, "sess-1", { onError: () => {} });
    expect(again.unresumable).toContain("does not match");
    expect(again.canResume).toBe(false);
    // The first reason is the cause; a later refusal does not overwrite it.
    again.markUnresumable("a --resume was refused (digest): later");
    expect(again.unresumable).toContain("does not match");
  });

  // The kill -9 gate's finding: the fold strips an open call from the assistant that made it, so the
  // resume seed's chain cannot equal the journal's. With calls open at `session_resumed`, the seed
  // is a whole-history `history_replaced` (reason `resume`), and the session stays resumable.
  it("journals the seed after a resume with open tool calls as a history_replaced", () => {
    const j = open();
    j.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s"), msg("user", "u")], digest: "sha256:d1", digests: ["sha256:d0", "sha256:d1"] });
    j.record({ type: "history_appended", run_id: "r0", step: 1, message: msg("assistant", "", { tool_calls: [{ id: "call_7", name: "bash", arguments: "{}" }] }), replaces_previous: false, digest_after: "sha256:d2" });
    expect(j.pendingToolCalls).toEqual(["call_7"]);
    j.record({
      type: "session_resumed",
      resume_count: 1, from_id: "0004", from_ordinal: 0,
      profile_from: "p", profile_to: "p",
      prompt_digest_from: "sha256:a", prompt_digest_to: "sha256:a", forced: false,
    });
    const stripped = [msg("system", "s"), msg("user", "u"), msg("assistant", "")];
    expect(j.record({ type: "history_seeded", run_id: "r1.0", messages: stripped, digest: "sha256:stripped", digests: ["x", "y", "sha256:stripped"] })).toBe(1);
    const last = lines(j).pop()!;
    expect(last.type).toBe("history_replaced");
    expect(last.reason).toBe("resume");
    expect(last.digest_after).toBe("sha256:stripped");
    expect(j.unresumable).toBeNull();
    expect(j.pendingToolCalls).toEqual([]);
  });

  // ...and an ordinary resume (no open calls, no checkpoint, same prompt) still compare-and-drops.
  it("still compares and drops the seed after an ordinary resume", () => {
    const j = open();
    j.record({ type: "history_seeded", run_id: "r0", messages: [msg("system", "s")], digest: "sha256:seed", digests: ["sha256:seed"] });
    j.record({
      type: "session_resumed",
      resume_count: 1, from_id: "0001", from_ordinal: 0,
      profile_from: "p", profile_to: "p",
      prompt_digest_from: "sha256:a", prompt_digest_to: "sha256:a", forced: false,
    });
    expect(j.record({ type: "history_seeded", run_id: "r1.0", messages: [msg("system", "s")], digest: "sha256:seed", digests: ["sha256:seed"] })).toBe(0);
    expect(lines(j).map((l) => l.type)).toEqual(["header", "history_appended", "resumed"]);
    expect(j.unresumable).toBeNull();
  });

  it("cannot resume a journal with no history yet", () => {
    const j = open();
    expect(j.canResume).toBe(false);
  });
});
