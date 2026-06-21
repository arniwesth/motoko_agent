import { afterEach, beforeEach, describe, expect, it } from "@jest/globals";
import { buildRuntimeChildEnv } from "./runtime-process.js";

describe("runtime child env", () => {
  let savedSessionId: string | undefined;
  let savedResume: string | undefined;

  beforeEach(() => {
    savedSessionId = process.env.MOTOKO_SESSION_ID;
    savedResume = process.env.MOTOKO_RESUME;
    delete process.env.MOTOKO_SESSION_ID;
    delete process.env.MOTOKO_RESUME;
  });

  afterEach(() => {
    if (savedSessionId === undefined) delete process.env.MOTOKO_SESSION_ID;
    else process.env.MOTOKO_SESSION_ID = savedSessionId;
    if (savedResume === undefined) delete process.env.MOTOKO_RESUME;
    else process.env.MOTOKO_RESUME = savedResume;
  });

  it("exports the stable TUI session id by default", () => {
    const env1 = buildRuntimeChildEnv("/tmp/work", "default", "session_stable", false);
    const env2 = buildRuntimeChildEnv("/tmp/work", "default", "session_stable", false);

    expect(env1.MOTOKO_SESSION_ID).toBe("session_stable");
    expect(env2.MOTOKO_SESSION_ID).toBe("session_stable");
    expect(env1.MOTOKO_RESUME).toBeUndefined();
  });

  it("preserves an adapter-provided MOTOKO_SESSION_ID", () => {
    process.env.MOTOKO_SESSION_ID = "session_from_env";
    const env = buildRuntimeChildEnv("/tmp/work", "default", "session_tui", false);

    expect(env.MOTOKO_SESSION_ID).toBe("session_from_env");
  });

  it("sets MOTOKO_RESUME only for interrupt respawns", () => {
    const normal = buildRuntimeChildEnv("/tmp/work", "default", "session_stable", false);
    const resumed = buildRuntimeChildEnv("/tmp/work", "default", "session_stable", true);

    expect(normal.MOTOKO_RESUME).toBeUndefined();
    expect(resumed.MOTOKO_RESUME).toBe("1");
  });
});
