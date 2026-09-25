import { describe, expect, it } from "@jest/globals";
import {
  argvAgentGet,
  argvAgentWaitSettled,
  herdrFailureCode,
  startWakeWaiter,
  type HerdrResult,
  type WaitDescriptor,
  type WaiterDeps,
  type WakeReply,
  type WakeRequest,
} from "./wake-waiter.js";

// PLAN-002 W4 gate 6: the host's observations for a park, without herdr and without a real clock.

const NOT_FOUND: HerdrResult = { code: 1, stdout: "", stderr: '{"error":{"code":"agent_not_found","message":"x"},"id":"cli:agent:get"}' };
const SERVER_DOWN: HerdrResult = { code: 1, stdout: "", stderr: '{"error":{"code":"server_not_running","message":"x"}}' };
const ROW: HerdrResult = {
  code: 0,
  stdout: '{"id":"cli:agent:get","result":{"agent":{"agent_status":"working","pane_id":"w1:p1"},"type":"agent_info"}}',
  stderr: "",
};

/** A herdr call that never returns on its own: it resolves only when the waiter cancels it. */
function hang(signal: AbortSignal): Promise<HerdrResult> {
  return new Promise((resolve) => {
    if (signal.aborted) resolve({ code: -1, stdout: "", stderr: "", spawnError: "cancelled" });
    signal.addEventListener("abort", () => resolve({ code: -1, stdout: "", stderr: "", spawnError: "cancelled" }));
  });
}

interface Fake {
  deps: WaiterDeps;
  answers: Map<string, string>;
  watchers: Map<string, () => void>;
  unsubscribed: string[];
  calls: string[][];
  signals: AbortSignal[];
}

function fake(herdr: (argv: string[], signal: AbortSignal, n: number) => Promise<HerdrResult>, readAnswer?: (p: string) => string | null): Fake {
  const answers = new Map<string, string>();
  const watchers = new Map<string, () => void>();
  const unsubscribed: string[] = [];
  const calls: string[][] = [];
  const signals: AbortSignal[] = [];
  const deps: WaiterDeps = {
    herdr: (argv, signal) => {
      calls.push(argv);
      signals.push(signal);
      return herdr(argv, signal, calls.length);
    },
    readAnswer: readAnswer ?? ((p) => answers.get(p) ?? null),
    watchAnswer: (p, onChange) => {
      watchers.set(p, onChange);
      return () => unsubscribed.push(p);
    },
    now: () => 1_000_000,
    setTimer: (fn, ms) => {
      const t = setTimeout(fn, ms);
      return () => clearTimeout(t);
    },
    defer: (fn) => {
      setImmediate(fn);
    },
    pollMs: 1,
  };
  return { deps, answers, watchers, unsubscribed, calls, signals };
}

const delegate = (id: string, kind = "claude"): WaitDescriptor => ({
  id,
  delegate_kind: kind,
  locator: { pane: `pane-${id}` },
  answer_path: `/tmp/answer-${id}.md`,
  run_key: `rk-${id}`,
});

const request = (waits: WaitDescriptor[]): WakeRequest => ({ type: "wake_request", request_id: "s.r0.1.p1", step: 3, attempt: 1, waits });

function run(req: WakeRequest, f: Fake): { reply: Promise<WakeReply>; replies: WakeReply[]; handle: ReturnType<typeof startWakeWaiter> } {
  const replies: WakeReply[] = [];
  let resolve!: (r: WakeReply) => void;
  const reply = new Promise<WakeReply>((r) => (resolve = r));
  const handle = startWakeWaiter(req, f.deps, (r) => {
    replies.push(r);
    resolve(r);
  });
  return { reply, replies, handle };
}

const tick = (ms = 30) => new Promise((r) => setTimeout(r, ms));

describe("wake waiter: DelegateWait answer observation", () => {
  it("settles on an answer already on disk (initial read), and cancels the losers", async () => {
    const f = fake((_a, s) => hang(s));
    f.answers.set("/tmp/answer-d0.md", "the answer");
    const { reply, replies } = run(request([delegate("d0")]), f);
    expect(await reply).toEqual({ request_id: "s.r0.1.p1", wait_id: "d0", outcome: "settled", detail: "the answer" });
    await tick();
    expect(replies).toHaveLength(1);
    expect(f.signals.every((s) => s.aborted)).toBe(true);
    expect(f.unsubscribed).toEqual(["/tmp/answer-d0.md"]);
  });

  it("reads, subscribes, then re-reads: an answer landing between the two reads is not missed", async () => {
    let reads = 0;
    const f = fake((_a, s) => hang(s), () => (++reads >= 2 ? "late" : null));
    const { reply } = run(request([delegate("d0")]), f);
    expect((await reply).detail).toBe("late");
    expect(reads).toBe(2);
    expect(f.watchers.has("/tmp/answer-d0.md")).toBe(true);
  });

  it("settles when the subscription fires", async () => {
    const f = fake((_a, s) => hang(s));
    const { reply, replies } = run(request([delegate("d0")]), f);
    await tick();
    expect(replies).toHaveLength(0);
    f.answers.set("/tmp/answer-d0.md", "written later");
    f.watchers.get("/tmp/answer-d0.md")!();
    expect(await reply).toMatchObject({ wait_id: "d0", outcome: "settled", detail: "written later" });
  });
});

describe("wake waiter: readiness order", () => {
  it("two answers ready at once resolve to the earlier wait", async () => {
    const f = fake((_a, s) => hang(s));
    f.answers.set("/tmp/answer-d0.md", "zero");
    f.answers.set("/tmp/answer-d1.md", "one");
    expect((await run(request([delegate("d1"), delegate("d0")]), f).reply).wait_id).toBe("d1");
    const g = fake((_a, s) => hang(s));
    g.answers.set("/tmp/answer-d0.md", "zero");
    g.answers.set("/tmp/answer-d1.md", "one");
    expect((await run(request([delegate("d0"), delegate("d1")]), g).reply).wait_id).toBe("d0");
  });

  it("a timer and an answer ready in the same pass follow `waits` order", async () => {
    const past = { id: "t0", deadline_ms: 0 };
    const f = fake((_a, s) => hang(s));
    f.answers.set("/tmp/answer-d0.md", "zero");
    expect(await run(request([past, delegate("d0")]), f).reply).toEqual({ request_id: "s.r0.1.p1", wait_id: "t0", outcome: "timed_out", detail: "" });
    const g = fake((_a, s) => hang(s));
    g.answers.set("/tmp/answer-d0.md", "zero");
    expect((await run(request([delegate("d0"), past]), g).reply).wait_id).toBe("d0");
  });

  it("herdr observations resolving in reverse order in one tick still report in `waits` order", async () => {
    const f = fake(async (argv) => {
      if (argv[1] === "get") return ROW;
      // d0's wait resolves several microtasks after d1's.
      if (argv[2] === "pane-d0") {
        for (let i = 0; i < 5; i++) await Promise.resolve();
      }
      return NOT_FOUND;
    });
    const { reply, replies } = run(request([delegate("d0"), delegate("d1")]), f);
    expect(await reply).toMatchObject({ wait_id: "d0", outcome: "lost" });
    await tick();
    expect(replies).toHaveLength(1);
  });
});

describe("wake waiter: DelegateWait state observation — HostError versus Lost", () => {
  it("a herdr transport failure on the wait is host_error, never lost", async () => {
    const f = fake(async (argv) => (argv[1] === "get" ? ROW : SERVER_DOWN));
    const r = await run(request([delegate("d0")]), f).reply;
    expect(r.outcome).toBe("host_error");
    expect(r.wait_id).toBe("");
    expect(r.detail).toContain("server_not_running");
  });

  it("a herdr binary that cannot be spawned is host_error", async () => {
    const f = fake(async () => ({ code: -1, stdout: "", stderr: "", spawnError: "ENOENT" }));
    expect(await run(request([delegate("d0")]), f).reply).toMatchObject({ outcome: "host_error", wait_id: "" });
    const g = fake(async () => {
      throw new Error("spawn exploded");
    });
    expect((await run(request([delegate("d0")]), g).reply).outcome).toBe("host_error");
  });

  it("unparseable `agent get` output is host_error", async () => {
    const f = fake(async () => ({ code: 0, stdout: "not json", stderr: "" }));
    expect((await run(request([delegate("d0")]), f).reply).outcome).toBe("host_error");
  });

  it("claude/codex: the row gone after it was seen, with no answer on re-read, is lost", async () => {
    const f = fake(async (argv) => (argv[1] === "get" ? ROW : NOT_FOUND));
    expect(await run(request([delegate("d0")]), f).reply).toMatchObject({ wait_id: "d0", outcome: "lost" });
    expect(f.calls[0]).toEqual(argvAgentGet("pane-d0"));
    expect(f.calls[1]).toEqual(["agent", "wait", "pane-d0", "--until", "idle", "--until", "done", "--until", "blocked"]);
  });

  it("claude/codex: the row gone, with the answer present on re-read, is settled", async () => {
    let reads = 0;
    const f = fake(async (argv) => (argv[1] === "get" ? ROW : NOT_FOUND), () => (++reads >= 3 ? "just in time" : null));
    expect(await run(request([delegate("d0")]), f).reply).toMatchObject({ outcome: "settled", detail: "just in time" });
  });

  it("claude/codex: a default-wait success is never an answer", async () => {
    const f = fake(async (argv, s) => (argv[1] === "wait" ? { code: 0, stdout: "{}", stderr: "" } : argv[1] === "get" && f.calls.length > 1 ? hang(s) : ROW));
    const { replies, handle } = run(request([delegate("d0")]), f);
    await tick();
    expect(replies).toHaveLength(0);
    handle.cancel();
  });

  it("motoko one-shot: agent_not_found BEFORE the row was seen is not lost; after it is", async () => {
    const sequence = [NOT_FOUND, NOT_FOUND, ROW, ROW, NOT_FOUND];
    const f = fake(async (_a, _s, n) => sequence[Math.min(n - 1, sequence.length - 1)]);
    expect(await run(request([delegate("m0", "motoko")]), f).reply).toMatchObject({ wait_id: "m0", outcome: "lost" });
    expect(f.calls).toHaveLength(5);
    expect(f.calls.every((c) => c[1] === "get")).toBe(true);
  });

  it("motoko one-shot: the row gone with an answer on re-read is settled", async () => {
    const sequence = [ROW, NOT_FOUND];
    let reads = 0;
    const f = fake(async (_a, _s, n) => sequence[Math.min(n - 1, 1)], () => (++reads >= 3 ? "published" : null));
    expect(await run(request([delegate("m0", "motoko")]), f).reply).toMatchObject({ outcome: "settled", detail: "published" });
  });

  it("classifies herdr failures like the extension", () => {
    expect(herdrFailureCode(NOT_FOUND)).toBe("agent_not_found");
    expect(herdrFailureCode(SERVER_DOWN)).toBe("server_not_running");
    expect(herdrFailureCode({ code: 2, stdout: "", stderr: "usage" })).toBe("cli_syntax");
    expect(herdrFailureCode(ROW)).toBe("");
    expect(argvAgentWaitSettled("x")).toEqual(["agent", "wait", "x", "--until", "idle", "--until", "done", "--until", "blocked"]);
  });
});

describe("wake waiter: timers, operator waits, cancellation", () => {
  it("TimerWait fires timed_out with its own id at its deadline", async () => {
    const f = fake((_a, s) => hang(s));
    const start = Date.now();
    f.deps.now = () => Date.now();
    const r = await run(request([{ id: "op" }, { id: "t1", deadline_ms: start + 20 }]), f).reply;
    expect(r).toEqual({ request_id: "s.r0.1.p1", wait_id: "t1", outcome: "timed_out", detail: "" });
    expect(Date.now() - start).toBeGreaterThanOrEqual(15);
  });

  it("an OperatorWait alone is never answered by the waiter", async () => {
    const f = fake((_a, s) => hang(s));
    const { replies, handle } = run(request([{ id: "op" }]), f);
    await tick();
    expect(replies).toHaveLength(0);
    expect(f.calls).toHaveLength(0);
    handle.cancel();
  });

  it("cancel kills herdr calls, closes subscriptions and timers, and nothing is reported after", async () => {
    const f = fake((_a, s) => hang(s));
    f.deps.now = () => Date.now();
    const { replies, handle } = run(request([delegate("d0"), { id: "t1", deadline_ms: Date.now() + 15 }]), f);
    await tick(5);
    handle.cancel();
    expect(handle.finished).toBe(true);
    expect(f.signals.length).toBeGreaterThan(0);
    expect(f.signals.every((s) => s.aborted)).toBe(true);
    expect(f.unsubscribed).toEqual(["/tmp/answer-d0.md"]);
    f.answers.set("/tmp/answer-d0.md", "too late");
    f.watchers.get("/tmp/answer-d0.md")!();
    await tick(40);
    expect(replies).toHaveLength(0);
  });
});
