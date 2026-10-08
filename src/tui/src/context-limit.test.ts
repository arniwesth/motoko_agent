import { afterEach, beforeEach, describe, expect, it } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
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
});
