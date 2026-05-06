// tui/src/models.ts
//
// Canonical list of known model identifiers shown in the /model SelectList.
// Format: "provider/model-name" — matches what AILANG passes to --ai.
//
// OpenRouter models use the config-driven streaming provider prefix
// "openrouter-config/" and can be fetched live from the OpenRouter API when
// OPENROUTER_API_KEY is set.
// Local OpenAI-compatible models are prefixed with "openai/" and fetched from
// OPENAI_BASE_URL when set.

export const KNOWN_MODELS: string[] = [
  "anthropic/claude-sonnet-4-6",
  "anthropic/claude-opus-4-6",
  "anthropic/claude-haiku-4-5",
  "openai/gpt-4o",
  "openai/gpt-4o-mini",
  "google/gemini-2.5-flash",
  "google/gemini-2.5-pro",
];

// Static fallback shown when OPENROUTER_API_KEY is set but the live fetch fails.
export const OPENROUTER_FALLBACK_MODELS: string[] = [
  "openrouter-config/anthropic/claude-sonnet-4-5",
  "openrouter-config/anthropic/claude-opus-4-5",
  "openrouter-config/openai/gpt-4o",
  "openrouter-config/openai/gpt-4o-mini",
  "openrouter-config/google/gemini-2.5-pro",
  "openrouter-config/google/gemini-2.5-flash",
  "openrouter-config/meta-llama/llama-3.3-70b-instruct",
  "openrouter-config/mistralai/mixtral-8x7b-instruct",
  "openrouter-config/deepseek/deepseek-r1",
  "openrouter-config/qwen/qwen-2.5-72b-instruct",
];

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
 * with "openrouter-config/". Falls back to OPENROUTER_FALLBACK_MODELS on error.
 */
export async function fetchOpenRouterModels(apiKey: string): Promise<string[]> {
  try {
    const res = await fetch("https://openrouter.ai/api/v1/models", {
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
    });
    if (!res.ok) {
      return OPENROUTER_FALLBACK_MODELS;
    }
    const json = (await res.json()) as { data?: Array<{ id: string }> };
    if (!Array.isArray(json.data)) {
      return OPENROUTER_FALLBACK_MODELS;
    }
    return json.data.map((m) => `openrouter-config/${m.id}`);
  } catch {
    return OPENROUTER_FALLBACK_MODELS;
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

  const [localOpenAIModels, openRouterModels] = await Promise.all([
    openAIBaseURL ? fetchLocalOpenAIModels(openAIBaseURL) : Promise.resolve([]),
    openRouterKey ? fetchOpenRouterModels(openRouterKey) : Promise.resolve([]),
  ]);

  return mergeUniqueModels(KNOWN_MODELS, localOpenAIModels, openRouterModels);
}
