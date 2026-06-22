// tui/src/models.ts
//
// Load the baseline model identifiers shown in the /model SelectList.
// Motoko keeps provider-like routing prefixes for most providers, but direct
// Google Gemini / Vertex uses bare "gemini-*" ids. In AILANG, "google/..."
// means an OpenRouter vendor/model id, not the direct Google provider.
//
// Static model ids live in .motoko/model-catalog.json so provider/catalog updates do
// not require TypeScript changes. Set MOTOKO_MODELS_FILE to point at an
// alternate JSON file.
//
// OpenRouter models are prefixed with "openrouter/" and can be fetched live
// from the OpenRouter API when OPENROUTER_API_KEY is set.
// Local OpenAI-compatible models are prefixed with "openai/" and fetched from
// OPENAI_BASE_URL when set.

import { existsSync, readFileSync } from "fs";
import path from "path";
import { fileURLToPath } from "url";

export type ModelsConfig = {
  known_models: string[];
  openrouter_fallback_models: string[];
};

export const DEFAULT_RUNTIME_MODEL = "anthropic/claude-sonnet-4-6";

const EMPTY_MODELS_CONFIG: ModelsConfig = {
  known_models: [],
  openrouter_fallback_models: [],
};

export function resolveRuntimeModel(
  env: NodeJS.ProcessEnv = process.env,
  profileModel?: string,
): string {
  const envModel = (env["MODEL"] ?? "").trim();
  if (envModel !== "") return envModel;

  const configuredModel = (profileModel ?? "").trim();
  if (configuredModel !== "") return configuredModel;

  return DEFAULT_RUNTIME_MODEL;
}

function stringArrayField(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === "string" && item.trim().length > 0);
}

function parseModelsConfig(raw: string): ModelsConfig {
  const parsed = JSON.parse(raw) as {
    known_models?: unknown;
    openrouter_fallback_models?: unknown;
  };
  return {
    known_models: stringArrayField(parsed.known_models),
    openrouter_fallback_models: stringArrayField(parsed.openrouter_fallback_models),
  };
}

function defaultModelsConfigCandidates(): string[] {
  const here = path.dirname(fileURLToPath(import.meta.url));
  return [
    path.join(process.cwd(), ".motoko", "model-catalog.json"),
    path.resolve(here, "..", "..", "..", ".motoko", "model-catalog.json"),
  ];
}

export function resolveModelsConfigPath(env: NodeJS.ProcessEnv = process.env): string | null {
  const explicit = (env["MOTOKO_MODELS_FILE"] ?? "").trim();
  if (explicit) {
    return path.resolve(explicit);
  }

  for (const candidate of defaultModelsConfigCandidates()) {
    if (existsSync(candidate)) {
      return candidate;
    }
  }
  return null;
}

export function loadModelsConfig(env: NodeJS.ProcessEnv = process.env): ModelsConfig {
  const filePath = resolveModelsConfigPath(env);
  if (!filePath) return EMPTY_MODELS_CONFIG;
  try {
    return parseModelsConfig(readFileSync(filePath, "utf8"));
  } catch {
    return EMPTY_MODELS_CONFIG;
  }
}

/**
 * Normalize OPENAI_BASE_URL for local OpenAI-compatible endpoints.
 * Returns null when the input is empty or invalid.
 */
export function normalizeOpenAIBaseURL(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;

  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    return null;
  }

  if (url.protocol !== "http:" && url.protocol !== "https:") {
    return null;
  }

  // Strip trailing slash and ensure /v1 suffix.
  let path = url.pathname.replace(/\/+$/, "");
  if (!path) {
    path = "/v1";
  } else if (!path.endsWith("/v1")) {
    path = `${path}/v1`;
  }
  url.pathname = path;
  url.search = "";
  url.hash = "";
  return url.toString().replace(/\/$/, "");
}

/**
 * Merge model lists while preserving order and removing duplicates.
 */
export function mergeUniqueModels(...lists: string[][]): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const list of lists) {
    for (const model of list) {
      if (!seen.has(model)) {
        seen.add(model);
        out.push(model);
      }
    }
  }
  return out;
}

/**
 * Fetch the live model list from OpenRouter and return model ids prefixed
 * with "openrouter/". Falls back to the configured OpenRouter models on error.
 */
export async function fetchOpenRouterModels(apiKey: string, fallbackModels: string[] = []): Promise<string[]> {
  try {
    const res = await fetch("https://openrouter.ai/api/v1/models", {
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
    });
    if (!res.ok) {
      return fallbackModels;
    }
    const json = (await res.json()) as { data?: Array<{ id: string }> };
    if (!Array.isArray(json.data)) {
      return fallbackModels;
    }
    return json.data.map((m) => `openrouter/${m.id}`);
  } catch {
    return fallbackModels;
  }
}

/**
 * Fetch model ids from an OpenAI-compatible endpoint and prefix them as
 * "openai/<id>". Returns [] on failure.
 */
export async function fetchLocalOpenAIModels(baseURL: string): Promise<string[]> {
  const normalized = normalizeOpenAIBaseURL(baseURL);
  if (!normalized) return [];
  try {
    const res = await fetch(`${normalized}/models`);
    if (!res.ok) return [];
    const json = (await res.json()) as { data?: Array<{ id?: string }> };
    if (!Array.isArray(json.data)) return [];
    return json.data
      .map((m) => (typeof m.id === "string" ? m.id : ""))
      .filter((id) => id.length > 0)
      .map((id) => `openai/${id}`);
  } catch {
    return [];
  }
}

/**
 * Resolve the full dynamic model list from environment variables.
 */
export async function fetchDynamicModelsFromEnv(
  env: NodeJS.ProcessEnv = process.env,
): Promise<string[]> {
  const openRouterKey = env["OPENROUTER_API_KEY"] ?? "";
  const openAIBaseURL = env["OPENAI_BASE_URL"] ?? "";
  const modelsConfig = loadModelsConfig(env);

  const [localOpenAIModels, openRouterModels] = await Promise.all([
    openAIBaseURL ? fetchLocalOpenAIModels(openAIBaseURL) : Promise.resolve([]),
    openRouterKey ? fetchOpenRouterModels(openRouterKey, modelsConfig.openrouter_fallback_models) : Promise.resolve([]),
  ]);

  return mergeUniqueModels(modelsConfig.known_models, localOpenAIModels, openRouterModels);
}
