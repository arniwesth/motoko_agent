import { afterEach, describe, expect, it, jest } from "@jest/globals";
import { mkdtempSync, rmSync, writeFileSync } from "fs";
import { tmpdir } from "os";
import path from "path";
import {
  DEFAULT_RUNTIME_MODEL,
  fetchDynamicModelsFromEnv,
  fetchLocalOpenAIModels,
  loadModelsConfig,
  mergeUniqueModels,
  normalizeOpenAIBaseURL,
  resolveRuntimeModel,
  resolveModelsConfigPath,
} from "./models.js";

describe("normalizeOpenAIBaseURL", () => {
  it("appends /v1 when missing", () => {
    expect(normalizeOpenAIBaseURL("http://localhost:8000")).toBe("http://localhost:8000/v1");
    expect(normalizeOpenAIBaseURL("http://localhost:8000/")).toBe("http://localhost:8000/v1");
    expect(normalizeOpenAIBaseURL("http://localhost:8000/openai")).toBe("http://localhost:8000/openai/v1");
  });

  it("keeps explicit /v1", () => {
    expect(normalizeOpenAIBaseURL("http://localhost:8000/v1")).toBe("http://localhost:8000/v1");
  });

  it("rejects invalid URLs", () => {
    expect(normalizeOpenAIBaseURL("")).toBeNull();
    expect(normalizeOpenAIBaseURL("not-a-url")).toBeNull();
    expect(normalizeOpenAIBaseURL("ftp://localhost:8000")).toBeNull();
  });
});

describe("mergeUniqueModels", () => {
  it("dedupes while preserving first-seen order", () => {
    const merged = mergeUniqueModels(
      ["openai/gpt-4o", "openai/a"],
      ["openai/a", "openrouter/x"],
      ["openai/gpt-4o", "openai/b"],
    );
    expect(merged).toEqual(["openai/gpt-4o", "openai/a", "openrouter/x", "openai/b"]);
  });
});

describe("resolveRuntimeModel", () => {
  it("uses MODEL env over profile model", () => {
    expect(resolveRuntimeModel({ MODEL: "openai/gpt-4o" }, "anthropic/claude-sonnet-4-6")).toBe("openai/gpt-4o");
  });

  it("uses profile model when MODEL env is empty", () => {
    expect(resolveRuntimeModel({}, "gemini-2.5-flash")).toBe("gemini-2.5-flash");
    expect(resolveRuntimeModel({ MODEL: "   " }, "openrouter/auto")).toBe("openrouter/auto");
  });

  it("falls back to the default runtime model", () => {
    expect(resolveRuntimeModel({}, "")).toBe(DEFAULT_RUNTIME_MODEL);
  });
});

function withTempModelsConfig(config: unknown): { env: NodeJS.ProcessEnv; cleanup: () => void } {
  const dir = mkdtempSync(path.join(tmpdir(), "motoko-models-"));
  const filePath = path.join(dir, "model-catalog.json");
  writeFileSync(filePath, JSON.stringify(config), "utf8");
  return {
    env: { MOTOKO_MODELS_FILE: filePath },
    cleanup: () => rmSync(dir, { recursive: true, force: true }),
  };
}

describe("loadModelsConfig", () => {
  it("loads known models and OpenRouter fallback models from JSON", () => {
    const { env, cleanup } = withTempModelsConfig({
      known_models: ["gemini-2.5-flash", "google/gemini-2.5-flash", ""],
      openrouter_fallback_models: ["openrouter/google/gemini-2.5-flash"],
      context_limits: {
        "gemini-2.5-flash": 1000000,
        "ignored-zero": 0,
        "ignored-string": "100",
      },
    });
    try {
      expect(resolveModelsConfigPath(env)).toBe(env.MOTOKO_MODELS_FILE);
      expect(loadModelsConfig(env)).toEqual({
        known_models: ["gemini-2.5-flash", "google/gemini-2.5-flash"],
        openrouter_fallback_models: ["openrouter/google/gemini-2.5-flash"],
        context_limits: {
          "gemini-2.5-flash": 1000000,
        },
      });
    } finally {
      cleanup();
    }
  });

  it("keeps direct Google/Vertex entries out of the OpenRouter google/ namespace", () => {
    const config = loadModelsConfig({});
    const directGoogleModels = config.known_models.filter((model) => model.startsWith("gemini-"));
    const openRouterGoogleModels = config.known_models.filter((model) => model.startsWith("google/"));

    expect(directGoogleModels.length).toBeGreaterThan(0);
    expect(openRouterGoogleModels).toEqual([]);
    expect(config.context_limits["gemini-2.5-flash"]).toBeGreaterThan(0);
  });
});

describe("fetchLocalOpenAIModels", () => {
  afterEach(() => {
    delete (globalThis as { fetch?: unknown }).fetch;
  });

  it("fetches and prefixes ids", async () => {
    const mockFetch = jest.fn(async () => ({
      ok: true,
      json: async () => ({ data: [{ id: "google/gemma-4-26B-A4B-it" }, { id: "qwen/qwen2.5" }] }),
    }));
    (globalThis as { fetch?: unknown }).fetch = mockFetch;

    const models = await fetchLocalOpenAIModels("http://127.0.0.1:8000");
    expect(models).toEqual([
      "openai/google/gemma-4-26B-A4B-it",
      "openai/qwen/qwen2.5",
    ]);
    expect(mockFetch).toHaveBeenCalledWith("http://127.0.0.1:8000/v1/models");
  });

  it("returns [] on fetch failure", async () => {
    const mockFetch = jest.fn(async () => ({ ok: false }));
    (globalThis as { fetch?: unknown }).fetch = mockFetch;

    const models = await fetchLocalOpenAIModels("http://127.0.0.1:8000");
    expect(models).toEqual([]);
  });
});

describe("fetchDynamicModelsFromEnv", () => {
  afterEach(() => {
    delete (globalThis as { fetch?: unknown }).fetch;
  });

  it("merges known + local + openrouter and dedupes", async () => {
    const { env: modelEnv, cleanup } = withTempModelsConfig({
      known_models: ["openai/gpt-4o", "gemini-2.5-flash"],
      openrouter_fallback_models: ["openrouter/fallback/model"],
    });
    const mockFetch = jest.fn(async (input: unknown) => {
      const url = String(input);
      if (url.includes("/v1/models") && url.includes("127.0.0.1")) {
        return {
          ok: true,
          json: async () => ({ data: [{ id: "google/gemma-4-26B-A4B-it" }, { id: "gpt-4o" }] }),
        };
      }
      if (url === "https://openrouter.ai/api/v1/models") {
        return {
          ok: true,
          json: async () => ({ data: [{ id: "openai/gpt-4o" }, { id: "meta-llama/llama-3.3-70b-instruct" }] }),
        };
      }
      return { ok: false };
    });
    (globalThis as { fetch?: unknown }).fetch = mockFetch;

    try {
      const models = await fetchDynamicModelsFromEnv({
        ...modelEnv,
        OPENAI_BASE_URL: "http://127.0.0.1:8000",
        OPENROUTER_API_KEY: "test-key",
      });

      expect(models).toContain("openai/google/gemma-4-26B-A4B-it");
      // Already in configured known models; should not duplicate.
      expect(models.filter((m) => m === "openai/gpt-4o")).toHaveLength(1);
      expect(models).toContain("openrouter/meta-llama/llama-3.3-70b-instruct");
    } finally {
      cleanup();
    }
  });

  it("uses configured OpenRouter fallback models when the live fetch fails", async () => {
    const { env: modelEnv, cleanup } = withTempModelsConfig({
      known_models: ["gemini-2.5-flash"],
      openrouter_fallback_models: ["openrouter/fallback/model"],
    });
    const mockFetch = jest.fn(async () => ({ ok: false }));
    (globalThis as { fetch?: unknown }).fetch = mockFetch;

    try {
      const models = await fetchDynamicModelsFromEnv({
        ...modelEnv,
        OPENROUTER_API_KEY: "test-key",
      });

      expect(models).toEqual(["gemini-2.5-flash", "openrouter/fallback/model"]);
    } finally {
      cleanup();
    }
  });
});
