import { afterEach, describe, expect, it, jest } from "@jest/globals";
import {
  fetchDynamicModelsFromEnv,
  fetchLocalOpenAIModels,
  mergeUniqueModels,
  normalizeOpenAIBaseURL,
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

    const models = await fetchDynamicModelsFromEnv({
      OPENAI_BASE_URL: "http://127.0.0.1:8000",
      OPENROUTER_API_KEY: "test-key",
    });

    expect(models).toContain("openai/google/gemma-4-26B-A4B-it");
    // Already in KNOWN_MODELS; should not duplicate.
    expect(models.filter((m) => m === "openai/gpt-4o")).toHaveLength(1);
    expect(models).toContain("openrouter/meta-llama/llama-3.3-70b-instruct");
  });
});
