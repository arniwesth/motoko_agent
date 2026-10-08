import { afterEach, beforeEach, describe, expect, it } from "@jest/globals";
import { spawnSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { fileURLToPath } from "url";
import { loadedCompactors, unknownContextLimitWarning, UnknownLimitWatch } from "./context-limit.js";
import { RuntimeProcess, type AgentEvent } from "./runtime-process.js";

// #237: a model that is in neither the profile nor the catalogue resolves `unknown`, both shipped
// compactors pass through on its 0, and the only trace was the record below.

// The record as the reporter's session log has it, with the `origin` and `run_id` the core also writes.
const UNKNOWN = {
  type: "context_limit_resolved",
  run_id: "s.r0.0",
  context_limit: 0,
  context_limit_source: {
    arm: "unknown",
    origin: "",
    profile_miss: "profile_key_absent",
    catalogue_miss: "model_not_in_catalogue",
    model: "openrouter/z-ai/glm-5.3-flash",
  },
};
const source = (over: Record<string, string>) => ({
  ...UNKNOWN,
  context_limit_source: { ...UNKNOWN.context_limit_source, ...over },
});
const BOUNDED = { ...source({ arm: "bounded", origin: "catalogue", profile_miss: "", catalogue_miss: "", model: "" }), context_limit: 262144 };
const DISABLED = source({ arm: "disabled", profile_miss: "", catalogue_miss: "", model: "" });
const sessionStart = (loaded_extensions: string[]) => ({ type: "session_start", task: "t", model: "m", loaded_extensions });
// With no catalogue the record names no model: the core fills `model` only for
// `model_not_in_catalogue`. These are the shapes a real two-model session wrote (the stub
// supervisor with MOTOKO_MODELS_FILE pointing at nothing, 2026-10-08): each run's own
// `session_start` names its model, and the record after it does not.
const ABSENT = source({ catalogue_miss: "catalogue_absent", model: "" });
const runStart = (model: string) => ({ schema_version: "1", session_id: "s", type: "session_start", task: "t", model, mode: "v2", run_id: "s.r0.0" });

describe("unknownContextLimitWarning", () => {
  it("names the model, both misses, the compactors that cannot run, and the two fixes", () => {
    const msg = unknownContextLimitWarning(UNKNOWN, ["scratchpad", "compaction_ai", "compaction_structural"]);
    expect(msg).toBe(
      "context limit unknown for openrouter/z-ai/glm-5.3-flash: the model is not in .motoko/model-catalog.json " +
        "and the profile sets no agent.context_limit. compaction_ai and compaction_structural cannot trigger " +
        "without a window, so this session's context will grow uncompacted. Set agent.context_limit in the " +
        "profile's config.json, or add the model under context_limits in .motoko/model-catalog.json.",
    );
  });

  it("says usage is unmeasured when no compactor is loaded", () => {
    const msg = unknownContextLimitWarning(UNKNOWN, ["scratchpad"]);
    expect(msg).toContain("Context usage is unmeasured for this session.");
    expect(msg).not.toContain("cannot trigger");
    expect(unknownContextLimitWarning(UNKNOWN)).toBe(msg);
  });

  it("names every miss the core can report", () => {
    const absent = unknownContextLimitWarning(source({ profile_miss: "profile_config_absent", catalogue_miss: "catalogue_absent", model: "" }));
    expect(absent).toContain("context limit unknown: .motoko/model-catalog.json was not found and the profile has no config.json.");
    const undecodable = unknownContextLimitWarning(source({ profile_miss: "profile_config_undecodable", catalogue_miss: "catalogue_undecodable", model: "" }));
    expect(undecodable).toContain(".motoko/model-catalog.json does not decode or has no context_limits and the profile's config.json does not decode.");
    expect(unknownContextLimitWarning(source({ profile_miss: "profile_key_non_positive" }))).toContain(
      "the profile's agent.context_limit is not a positive number",
    );
  });

  it("names the run's model when the record names none, and the record's own when it does", () => {
    expect(unknownContextLimitWarning(ABSENT, [], "stub-first")).toContain(
      "context limit unknown for stub-first: .motoko/model-catalog.json was not found and the profile sets no agent.context_limit.",
    );
    expect(unknownContextLimitWarning(UNKNOWN, [], "another-model")).toContain("context limit unknown for openrouter/z-ai/glm-5.3-flash: ");
  });

  it("shows a miss id it has no sentence for instead of dropping it", () => {
    expect(unknownContextLimitWarning(source({ catalogue_miss: "catalogue_stale" }))).toContain(
      "glm-5.3-flash: catalogue_stale and the profile sets no agent.context_limit.",
    );
  });

  it("is silent for a bounded or a declared-disabled limit, and for anything else", () => {
    expect(unknownContextLimitWarning(BOUNDED, ["compaction_ai"])).toBeNull();
    expect(unknownContextLimitWarning(DISABLED, ["compaction_ai"])).toBeNull();
    expect(unknownContextLimitWarning({ type: "context_limit_resolved", context_limit: 0 })).toBeNull();
    expect(unknownContextLimitWarning({ type: "thinking", step: 1, text: "unknown" })).toBeNull();
    expect(unknownContextLimitWarning(null)).toBeNull();
  });

  it("takes the compactors by prefix", () => {
    expect(loadedCompactors(["mcp", "compaction_ai", "scratchpad", "compaction_structural"])).toEqual([
      "compaction_ai",
      "compaction_structural",
    ]);
    expect(loadedCompactors([])).toEqual([]);
  });
});

describe("UnknownLimitWatch", () => {
  it("warns once for the same resolution across runs, with the compactors session_start named", () => {
    const watch = new UnknownLimitWatch();
    expect(watch.observe(sessionStart(["compaction_ai"]))).toBeNull();
    expect(watch.observe(UNKNOWN)).toContain("compaction_ai cannot trigger");
    // The next turn is a new run and re-emits the record; a turn's own session_start names no extensions.
    expect(watch.observe({ type: "session_start", task: "t2", model: "m" })).toBeNull();
    expect(watch.observe({ ...UNKNOWN, run_id: "s.r0.1" })).toBeNull();
  });

  it("warns again for another unknown model, and after the limit was bounded in between", () => {
    const watch = new UnknownLimitWatch();
    expect(watch.observe(UNKNOWN)).not.toBeNull();
    expect(watch.observe(source({ model: "openrouter/moonshotai/kimi-k3" }))).toContain("kimi-k3");
    expect(watch.observe(BOUNDED)).toBeNull();
    expect(watch.observe(source({ model: "openrouter/moonshotai/kimi-k3" }))).not.toBeNull();
  });
});

describe("UnknownLimitWatch with no catalogue", () => {
  it("names each run's model and warns again when the model changes", () => {
    const watch = new UnknownLimitWatch();
    expect(watch.observe(runStart("stub-first"))).toBeNull();
    expect(watch.observe(ABSENT)).toContain("context limit unknown for stub-first: ");
    expect(watch.observe(runStart("stub-first"))).toBeNull();
    expect(watch.observe(ABSENT)).toBeNull();
    expect(watch.observe(runStart("stub-second"))).toBeNull();
    expect(watch.observe(ABSENT)).toContain("context limit unknown for stub-second: ");
  });
});

describe("RuntimeProcess and an unknown context limit", () => {
  let workdir: string;
  let savedBin: string | undefined;

  beforeEach(() => {
    workdir = fs.mkdtempSync(path.join(os.tmpdir(), "unknown-limit-"));
    savedBin = process.env.AILANG_BIN;
  });

  afterEach(() => {
    if (savedBin === undefined) delete process.env.AILANG_BIN;
    else process.env.AILANG_BIN = savedBin;
    fs.rmSync(workdir, { recursive: true, force: true });
  });

  /** Spawn a RuntimeProcess whose "ailang" prints `lines`; resolve with its events once it has exited. */
  function run(lines: unknown[]): Promise<AgentEvent[]> {
    const bin = path.join(workdir, "fake-ailang.sh");
    const script = lines.map((l) => `printf '%s\\n' '${JSON.stringify(l)}'`).join("\n");
    fs.writeFileSync(bin, `#!/bin/sh\n${script}\n`, { mode: 0o755 });
    process.env.AILANG_BIN = bin;
    const events: AgentEvent[] = [];
    return new Promise((resolve) => {
      new RuntimeProcess(
        "task", "http://127.0.0.1:1", "test-model", workdir, "default", 1, "", "", "",
        (e) => events.push(e),
        () => resolve(events),
      );
    });
  }

  const done = { type: "done", step: 1, output: "ok" };

  it("raises one warning, right after the record, for a two-run session", async () => {
    const events = await run([sessionStart(["compaction_ai"]), UNKNOWN, done, { ...UNKNOWN, run_id: "s.r0.1" }, done]);
    expect(events.map((e) => e.type)).toEqual([
      "session_start", "context_limit_resolved", "warning", "done", "context_limit_resolved", "done",
    ]);
    expect((events[2] as { message: string }).message).toContain("compaction_ai cannot trigger without a window");
  });

  it("raises none when the limit is bounded", async () => {
    const events = await run([sessionStart(["compaction_ai"]), BOUNDED, done]);
    expect(events.filter((e) => e.type === "warning")).toHaveLength(0);
  });

  it("raises one per model when there is no catalogue to name them", async () => {
    const events = await run([
      sessionStart(["compaction_ai"]), runStart("stub-first"), ABSENT, done, runStart("stub-second"), ABSENT, done,
    ]);
    const warnings = events.filter((e) => e.type === "warning").map((e) => (e as { message: string }).message);
    expect(warnings).toHaveLength(2);
    expect(warnings[0]).toContain("context limit unknown for stub-first: ");
    expect(warnings[1]).toContain("context limit unknown for stub-second: ");
  });
});

// The plain logger is a class inside index.ts, which runs `main()` on import, so the only way to
// hold its `warning` arm is to run the host: headless, with a shell script as the runtime. The
// host names its session log and journal after MOTOKO_SESSION_ID under the repo's .motoko/, so
// the test names the session and removes exactly those three paths.
describe("the plain headless logger", () => {
  const index = fileURLToPath(new URL("./index.ts", import.meta.url));
  const projectRoot = path.resolve(path.dirname(index), "../../..");
  const sessionId = `plain-warning-test-${process.pid}`;
  let workdir: string;

  beforeEach(() => {
    workdir = fs.mkdtempSync(path.join(os.tmpdir(), "plain-warning-"));
  });

  afterEach(() => {
    fs.rmSync(workdir, { recursive: true, force: true });
    for (const leftover of [
      path.join(projectRoot, ".motoko", "logfile", `${sessionId}.jsonl`),
      path.join(projectRoot, ".motoko", "logfile", `${sessionId}.md`),
      path.join(projectRoot, ".motoko", "sessions", sessionId),
    ]) fs.rmSync(leftover, { recursive: true, force: true });
  });

  it("prints a warning event on stderr and still finishes the run", () => {
    const bin = path.join(workdir, "fake-ailang.sh");
    const lines = [{ ...sessionStart(["compaction_ai"]), model: "m-one" }, ABSENT, { type: "done", step: 1, output: "ok" }];
    // Only `run` is the runtime; any other invocation of the binary says nothing.
    const script = lines.map((l) => `printf '%s\\n' '${JSON.stringify(l)}'`).join("\n");
    fs.writeFileSync(bin, `#!/bin/sh\n[ "$1" = run ] || exit 0\n${script}\n`, { mode: 0o755 });
    const bun = (process.versions as Record<string, string | undefined>).bun ? process.execPath : "bun";
    const result = spawnSync(bun, [index, "hi"], {
      encoding: "utf8",
      timeout: 60_000,
      env: {
        ...process.env,
        MOTOKO_HEADLESS: "1",
        MOTOKO_JSONL_OUTPUT: "",
        MOTOKO_CONFIG: "default",
        MOTOKO_SESSION_ID: sessionId,
        AILANG_BIN: bin,
        WORKDIR: workdir,
        ENV_PORT: "0",
        MODEL: "m-one",
      },
    });
    expect(result.stderr).toContain("[warning] context limit unknown for m-one: .motoko/model-catalog.json was not found");
    expect(result.stdout).toContain("[done] 1 step(s)");
    expect(result.status).toBe(0);
  });
});
