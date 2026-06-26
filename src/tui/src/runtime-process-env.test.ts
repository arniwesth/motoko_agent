import { describe, expect, it } from "@jest/globals";
import { autoForwardedEnvKeys } from "./runtime-process.js";
import { CORE_MAP, EXTENSION_MAPS } from "./config.js";

// Drift-guard for the recurring "env var scrubbed by the childEnv allowlist → feature
// silently off" bug (hit 5×: SYSTEM_MD, MOTOKO_REPO, MOTOKO_PERSIST_RETRIES,
// AILANG_OLLAMA_MAX_TOKENS, AILANG_STDLIB_PATH). The allowlist must be DERIVED from the
// config maps + the motoko/ailang namespaces, never hand-maintained as a second source of
// truth. These tests fail loudly if forwarding ever stops covering a config-mapped var.
describe("autoForwardedEnvKeys — env-forward drift guard", () => {
  it("forwards every CORE_MAP env var (incl. SYSTEM_MD)", () => {
    const keys = new Set(autoForwardedEnvKeys({}));
    for (const { env } of Object.values(CORE_MAP)) {
      expect(keys.has(env)).toBe(true);
    }
    expect(keys.has("SYSTEM_MD")).toBe(true); // agent.system_prompt — the 4-day bug
  });

  it("forwards every EXTENSION_MAPS env var", () => {
    const keys = new Set(autoForwardedEnvKeys({}));
    for (const map of Object.values(EXTENSION_MAPS)) {
      for (const { env } of Object.values(map)) {
        expect(keys.has(env)).toBe(true);
      }
    }
  });

  it("auto-forwards motoko/ailang-namespaced vars but not arbitrary host vars", () => {
    const keys = new Set(
      autoForwardedEnvKeys({
        SYSTEM_MD: "x",
        MOTOKO_BRAND_NEW_FEATURE: "y",
        AILANG_BRAND_NEW_FLAG: "z",
        HOME: "/home/nobody",
        SECRET_TOKEN: "should-not-leak",
      }),
    );
    expect(keys.has("MOTOKO_BRAND_NEW_FEATURE")).toBe(true);
    expect(keys.has("AILANG_BRAND_NEW_FLAG")).toBe(true);
    expect(keys.has("SECRET_TOKEN")).toBe(false);
  });
});
