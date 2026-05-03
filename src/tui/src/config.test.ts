import { afterEach, beforeEach, describe, expect, it, jest } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { activeProfile, loadMotokoConfig, resolveProfileDir } from "./config.js";

const ENV_KEYS = [
  "WORKDIR",
  "MOTOKO_CONFIG",
  "MODEL",
  "AI_MAX_STEPS",
  "HYBRID_TOOLS",
  "OHMY_PI_TOOLS",
  "AILANG_SNIPPET_CAPS",
  "CORE_EXT_ORDER",
  "MOTOKO_JSONL_OUTPUT",
  "MOTOKO_AI_OPTIONS_JSON",
  "SYSTEM_MD",
  "AILANG_COMPOSITION_MODE",
  "AILANG_SUBAGENT_MODEL",
  "AILANG_COMPOSE_CLAIMCHECK",
  "CONTEXT_MODE_BIN",
];

let originalEnv: NodeJS.ProcessEnv;
let tempDir: string;

function writeConfig(relativePath: string, content: string): void {
  const fullPath = path.join(tempDir, relativePath);
  fs.mkdirSync(path.dirname(fullPath), { recursive: true });
  fs.writeFileSync(fullPath, content, "utf8");
}

describe("loadMotokoConfig", () => {
  beforeEach(() => {
    originalEnv = { ...process.env };
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "motoko-config-"));
    for (const key of ENV_KEYS) delete process.env[key];
    process.env.WORKDIR = tempDir;
  });

  afterEach(() => {
    process.env = originalEnv;
    fs.rmSync(tempDir, { recursive: true, force: true });
    jest.restoreAllMocks();
  });

  it("parses config.toml and writes mapped env vars", () => {
    writeConfig(".motoko/config.toml", `
[agent]
model = "openai/gpt-4o"
max_steps = 12
ai_options_json = '{"chat_template_kwargs":{"enable_thinking":true}}'

[tools]
hybrid = true
snippet_caps = ["IO", "FS", "Process"]

[extensions]
order = ["compose", "omnigraph"]

[ui]
jsonl_output = true
`);

    loadMotokoConfig();

    expect(process.env.MODEL).toBe("openai/gpt-4o");
    expect(process.env.AI_MAX_STEPS).toBe("12");
    expect(process.env.MOTOKO_AI_OPTIONS_JSON).toBe('{"chat_template_kwargs":{"enable_thinking":true}}');
    expect(process.env.HYBRID_TOOLS).toBe("1");
    expect(process.env.AILANG_SNIPPET_CAPS).toBe("IO,FS,Process");
    expect(process.env.CORE_EXT_ORDER).toBe("compose,omnigraph");
    expect(process.env.MOTOKO_JSONL_OUTPUT).toBe("1");
  });

  it("does nothing when .motoko is missing", () => {
    loadMotokoConfig();

    expect(process.env.MODEL).toBeUndefined();
    expect(process.env.HYBRID_TOOLS).toBeUndefined();
  });

  it("skips missing keys without injecting defaults", () => {
    writeConfig(".motoko/config.toml", `
[agent]
model = "anthropic/custom"
`);

    loadMotokoConfig();

    expect(process.env.MODEL).toBe("anthropic/custom");
    expect(process.env.AI_MAX_STEPS).toBeUndefined();
  });

  it("does not override protected env vars", () => {
    process.env.MODEL = "shell/model";
    process.env.HYBRID_TOOLS = "0";
    writeConfig(".motoko/config.toml", `
[agent]
model = "openai/gpt-4o"

[tools]
hybrid = true
`);

    loadMotokoConfig({ protectedKeys: new Set(["MODEL", "HYBRID_TOOLS"]) });

    expect(process.env.MODEL).toBe("shell/model");
    expect(process.env.HYBRID_TOOLS).toBe("0");
  });

  it("overrides existing non-protected env vars from .env or .export", () => {
    process.env.CORE_EXT_ORDER = "test_dummy";
    writeConfig(".motoko/config.toml", `
[extensions]
order = ["context_mode", "exa_search"]
`);

    loadMotokoConfig({ protectedKeys: new Set() });

    expect(process.env.CORE_EXT_ORDER).toBe("context_mode,exa_search");
  });

  it("serializes false booleans to 0", () => {
    writeConfig(".motoko/config.toml", `
[tools]
ohmy_pi = false
`);

    loadMotokoConfig();

    expect(process.env.OHMY_PI_TOOLS).toBe("0");
  });

  it("skips empty strings and empty arrays", () => {
    writeConfig(".motoko/config.toml", `
[agent]
system_prompt = ""

[extensions]
order = []
`);

    loadMotokoConfig();

    expect(process.env.SYSTEM_MD).toBeUndefined();
    expect(process.env.CORE_EXT_ORDER).toBeUndefined();
  });

  it("loads extension config for resolved active extensions", () => {
    writeConfig(".motoko/config.toml", `
[extensions]
order = ["compose", "context_mode"]
`);
    writeConfig(".motoko/compose.toml", `
[compose]
mode = "subagent"
subagent_model = ""

[compose.claimcheck]
enabled = false
`);
    writeConfig(".motoko/context_mode.toml", `
[context_mode]
bin = "ctx-custom"
`);

    loadMotokoConfig();

    expect(process.env.AILANG_COMPOSITION_MODE).toBe("subagent");
    expect(process.env.AILANG_SUBAGENT_MODEL).toBeUndefined();
    expect(process.env.AILANG_COMPOSE_CLAIMCHECK).toBe("0");
    expect(process.env.CONTEXT_MODE_BIN).toBe("ctx-custom");
  });

  it("uses protected CORE_EXT_ORDER to decide extension files", () => {
    process.env.CORE_EXT_ORDER = "context_mode";
    writeConfig(".motoko/config.toml", `
[extensions]
order = ["compose"]
`);
    writeConfig(".motoko/context_mode.toml", `
[context_mode]
bin = "ctx-shell-order"
`);

    loadMotokoConfig({ protectedKeys: new Set(["CORE_EXT_ORDER"]) });

    expect(process.env.CORE_EXT_ORDER).toBe("context_mode");
    expect(process.env.CONTEXT_MODE_BIN).toBe("ctx-shell-order");
  });

  it("warns and continues on invalid TOML", () => {
    const warn = jest.spyOn(console, "warn").mockImplementation(() => {});
    writeConfig(".motoko/config.toml", `
[agent
model = "broken"
`);

    expect(() => loadMotokoConfig()).not.toThrow();
    expect(process.env.MODEL).toBeUndefined();
    expect(warn).toHaveBeenCalledTimes(1);
  });

  it("loads from a named profile directory", () => {
    process.env.MOTOKO_CONFIG = "benchmark";
    writeConfig(".motoko/config/benchmark/config.toml", `
[agent]
model = "openai/benchmark"
`);

    loadMotokoConfig();

    expect(activeProfile()).toBe("benchmark");
    expect(resolveProfileDir()).toBe(path.join(tempDir, ".motoko", "config", "benchmark"));
    expect(process.env.MODEL).toBe("openai/benchmark");
  });

  it("loads from the default profile when MOTOKO_CONFIG is unset", () => {
    writeConfig(".motoko/config/default/config.toml", `
[agent]
model = "anthropic/default"
`);

    loadMotokoConfig();

    expect(activeProfile()).toBe("default");
    expect(resolveProfileDir()).toBe(path.join(tempDir, ".motoko", "config", "default"));
    expect(process.env.MODEL).toBe("anthropic/default");
  });

  it("loads from an absolute MOTOKO_CONFIG path", () => {
    const profileDir = path.join(tempDir, "external-profile");
    process.env.MOTOKO_CONFIG = profileDir;
    writeConfig("external-profile/config.toml", `
[agent]
model = "openai/external"
`);

    loadMotokoConfig();

    expect(resolveProfileDir()).toBe(profileDir);
    expect(process.env.MODEL).toBe("openai/external");
  });

  it("falls back to flat layout and emits a deprecation warning", () => {
    const stderr = jest.spyOn(process.stderr, "write").mockImplementation(() => true);
    writeConfig(".motoko/config.toml", `
[agent]
model = "anthropic/flat"
`);

    loadMotokoConfig();

    expect(process.env.MODEL).toBe("anthropic/flat");
    expect(stderr).toHaveBeenCalledWith(expect.stringContaining("Deprecated flat config layout"));
  });

  it("loads extension config from the active profile directory", () => {
    process.env.MOTOKO_CONFIG = "debug";
    writeConfig(".motoko/config/debug/config.toml", `
[extensions]
order = ["compose", "context_mode"]
`);
    writeConfig(".motoko/config/debug/compose.toml", `
[compose]
mode = "profile-subagent"

[compose.claimcheck]
enabled = true
`);
    writeConfig(".motoko/config/debug/context_mode.toml", `
[context_mode]
bin = "ctx-profile"
`);

    loadMotokoConfig();

    expect(process.env.CORE_EXT_ORDER).toBe("compose,context_mode");
    expect(process.env.AILANG_COMPOSITION_MODE).toBe("profile-subagent");
    expect(process.env.AILANG_COMPOSE_CLAIMCHECK).toBe("1");
    expect(process.env.CONTEXT_MODE_BIN).toBe("ctx-profile");
  });

  it("uses profile config over flat config without warning when both exist", () => {
    const stderr = jest.spyOn(process.stderr, "write").mockImplementation(() => true);
    process.env.MOTOKO_CONFIG = "benchmark";
    writeConfig(".motoko/config.toml", `
[agent]
model = "anthropic/flat"
`);
    writeConfig(".motoko/config/benchmark/config.toml", `
[agent]
model = "openai/profile"
`);

    loadMotokoConfig();

    expect(process.env.MODEL).toBe("openai/profile");
    expect(stderr).not.toHaveBeenCalled();
  });
});
