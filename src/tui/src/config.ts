import * as fs from "fs";
import * as path from "path";
import { parse } from "smol-toml";

type Serialize = (value: unknown) => string | undefined;

export type ConfigMap = Record<string, { env: string; serialize?: Serialize }>;
export type LoadMotokoConfigOptions = {
  protectedKeys?: Set<string>;
};

const CSV: Serialize = (value) => {
  if (!Array.isArray(value)) return undefined;
  return value.map((item) => String(item)).join(",");
};

const boolTo01: Serialize = (value) => {
  if (typeof value !== "boolean") return undefined;
  return value ? "1" : "0";
};

export const CORE_MAP: ConfigMap = {
  "agent.model": { env: "MODEL" },
  "agent.workdir": { env: "WORKDIR" },
  "agent.max_steps": { env: "AI_MAX_STEPS" },
  "agent.step_delay_ms": { env: "AI_STEP_DELAY_MS" },
  "agent.max_retries": { env: "AI_MAX_RETRIES" },
  "agent.retry_base_ms": { env: "AI_RETRY_BASE_MS" },
  "agent.retry_cap_ms": { env: "AI_RETRY_CAP_MS" },
  "agent.system_prompt": { env: "SYSTEM_MD" },
  "agent.openai_base_url": { env: "OPENAI_BASE_URL" },
  "agent.ai_options_json": { env: "MOTOKO_AI_OPTIONS_JSON" },
  "server.port": { env: "ENV_PORT" },
  "tools.hybrid": { env: "HYBRID_TOOLS", serialize: boolTo01 },
  "tools.ohmy_pi": { env: "OHMY_PI_TOOLS", serialize: boolTo01 },
  "tools.eval_ws_loopback": { env: "MOTOKO_EVAL_WS_LOOPBACK", serialize: boolTo01 },
  "tools.snippet_caps": { env: "AILANG_SNIPPET_CAPS", serialize: CSV },
  "tools.delegated_timeout_ms": { env: "DELEGATED_TOOL_TIMEOUT_MS" },
  "tools.delegated_poll_ms": { env: "DELEGATED_TOOL_POLL_MS" },
  "tools.delegated_timeout_slack_ms": { env: "DELEGATED_TOOL_TIMEOUT_SLACK_MS" },
  "tools.edit_mode": { env: "EDIT_MODE" },
  "extensions.order": { env: "CORE_EXT_ORDER", serialize: CSV },
  "extensions.strict": { env: "CORE_EXT_STRICT", serialize: boolTo01 },
  "ui.stream_events": { env: "MOTOKO_STREAM_EVENTS", serialize: boolTo01 },
  "ui.jsonl_output": { env: "MOTOKO_JSONL_OUTPUT", serialize: boolTo01 },
  "ui.plain_verbose_stream": { env: "MOTOKO_PLAIN_VERBOSE_STREAM", serialize: boolTo01 },
  "ui.show_tool_json_stream": { env: "MOTOKO_SHOW_TOOL_JSON_STREAM", serialize: boolTo01 },
  "ui.final_only": { env: "MOTOKO_FINAL_ONLY", serialize: boolTo01 },
  "ui.activity_log": { env: "TUI_ACTIVITY_LOG", serialize: boolTo01 },
  "ui.subagent_verbose": { env: "AILANG_SUBAGENT_VERBOSE", serialize: boolTo01 },
  "ui.subagent_auto_collapse": { env: "AILANG_SUBAGENT_AUTO_COLLAPSE", serialize: boolTo01 },
  "ui.force_tty": { env: "FORCE_TTY", serialize: boolTo01 },
  "runtime.ailang_bin": { env: "AILANG_BIN" },
  "verification.semi_formal": { env: "SEMI_FORMAL_VERIFIER_MODE", serialize: boolTo01 },
};

export const EXTENSION_MAPS: Record<string, ConfigMap> = {
  compose: {
    "compose.mode": { env: "AILANG_COMPOSITION_MODE" },
    "compose.subagent_model": { env: "AILANG_SUBAGENT_MODEL" },
    "compose.max_attempts": { env: "AILANG_SUBAGENT_MAX_ATTEMPTS" },
    "compose.effect_guard": { env: "AILANG_COMPOSE_EFFECT_GUARD" },
    "compose.certificate_template": { env: "AILANG_COMPOSE_CERTIFICATE_TEMPLATE", serialize: boolTo01 },
    "compose.authoring.structured": { env: "AILANG_COMPOSE_STRUCTURED_AUTHORING", serialize: boolTo01 },
    "compose.authoring.author_tools": { env: "AILANG_COMPOSE_AUTHOR_TOOLS", serialize: boolTo01 },
    "compose.authoring.author_tools_budget": { env: "AILANG_COMPOSE_AUTHOR_TOOLS_BUDGET" },
    "compose.authoring.author_tools_max_bytes": { env: "AILANG_COMPOSE_AUTHOR_TOOLS_MAX_BYTES" },
    "compose.authoring.author_tools_max_turns": { env: "AILANG_COMPOSE_AUTHOR_TOOLS_MAX_TURNS" },
    "compose.authoring.author_tools_deny_globs": { env: "AILANG_COMPOSE_AUTHOR_TOOLS_DENY_GLOBS" },
    "compose.authoring.authoring_budget": { env: "AILANG_COMPOSE_AUTHORING_BUDGET" },
    "compose.authoring.fallback_after": { env: "AILANG_COMPOSE_STRUCTURED_AUTHORING_FALLBACK_AFTER" },
    "compose.authoring.min_observed_chars": { env: "AILANG_COMPOSE_MIN_OBSERVED_CHARS" },
    "compose.authoring.stdout_max_bytes": { env: "AILANG_COMPOSE_STDOUT_MAX_BYTES" },
    "compose.claimcheck.enabled": { env: "AILANG_COMPOSE_CLAIMCHECK", serialize: boolTo01 },
    "compose.claimcheck.informalizer_model": { env: "AILANG_COMPOSE_CLAIMCHECK_INFORMALIZER_MODEL" },
    "compose.claimcheck.comparator_model": { env: "AILANG_COMPOSE_CLAIMCHECK_COMPARATOR_MODEL" },
    "compose.claimcheck.timeout_ms": { env: "AILANG_COMPOSE_CLAIMCHECK_TIMEOUT_MS" },
    "compose.claimcheck.max_invocations": { env: "AILANG_COMPOSE_CLAIMCHECK_MAX_INVOCATIONS" },
    "compose.claimcheck.stdout_max_bytes": { env: "AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES" },
    "compose.claimcheck.ledger_in_informalizer": { env: "AILANG_COMPOSE_CLAIMCHECK_LEDGER_IN_INFORMALIZER", serialize: boolTo01 },
  },
  context_mode: {
    "context_mode.bin": { env: "CONTEXT_MODE_BIN" },
    "context_mode.snapshot_key_prefix": { env: "CONTEXT_MODE_SNAPSHOT_KEY_PREFIX" },
  },
  exa_search: {},
  omnigraph: {},
};

export const CORE_CONFIG_TEMPLATE = `# Motoko project config. Shell environment variables override these values.
# .env/.export files are loaded first and provide fallback values or secrets.

[agent]
model = "anthropic/claude-sonnet-4-6"   # MODEL
workdir = "."                            # WORKDIR
max_steps = 50                           # AI_MAX_STEPS
step_delay_ms = 0                        # AI_STEP_DELAY_MS
max_retries = 3                          # AI_MAX_RETRIES
retry_base_ms = 1000                     # AI_RETRY_BASE_MS
retry_cap_ms = 30000                     # AI_RETRY_CAP_MS
system_prompt = ""                       # SYSTEM_MD
openai_base_url = ""                     # OPENAI_BASE_URL
ai_options_json = ""                     # MOTOKO_AI_OPTIONS_JSON

[server]
port = 8080                              # ENV_PORT

[tools]
hybrid = true                            # HYBRID_TOOLS
ohmy_pi = false                          # OHMY_PI_TOOLS
eval_ws_loopback = false                 # MOTOKO_EVAL_WS_LOOPBACK
snippet_caps = ["IO", "FS", "Process"]   # AILANG_SNIPPET_CAPS
delegated_timeout_ms = 30000             # DELEGATED_TOOL_TIMEOUT_MS
delegated_poll_ms = 100                  # DELEGATED_TOOL_POLL_MS
delegated_timeout_slack_ms = 5000        # DELEGATED_TOOL_TIMEOUT_SLACK_MS
edit_mode = ""                           # EDIT_MODE

[extensions]
# Extensions load in this order. Matching .motoko/config/<profile>/<extension>.toml
# files are loaded only for extensions listed here.
order = []                               # CORE_EXT_ORDER
strict = false                           # CORE_EXT_STRICT

[ui]
stream_events = true                     # MOTOKO_STREAM_EVENTS
jsonl_output = false                     # MOTOKO_JSONL_OUTPUT
plain_verbose_stream = false             # MOTOKO_PLAIN_VERBOSE_STREAM
show_tool_json_stream = false            # MOTOKO_SHOW_TOOL_JSON_STREAM
final_only = false                       # MOTOKO_FINAL_ONLY
activity_log = false                     # TUI_ACTIVITY_LOG
subagent_verbose = false                 # AILANG_SUBAGENT_VERBOSE
subagent_auto_collapse = false           # AILANG_SUBAGENT_AUTO_COLLAPSE
force_tty = false                        # FORCE_TTY

[runtime]
ailang_bin = ""                          # AILANG_BIN

[verification]
semi_formal = false                      # SEMI_FORMAL_VERIFIER_MODE
`;

export const CORE_CONFIG_JSON_TEMPLATE = JSON.stringify(
  {
    agent: {
      model: "anthropic/claude-sonnet-4-6",
      workdir: ".",
      max_steps: 50,
      step_delay_ms: 0,
      max_retries: 3,
      retry_base_ms: 1000,
      retry_cap_ms: 30000,
      semi_formal_verifier_mode: false,
      system_prompt: "",
      openai_base_url: "",
      ai_options_json: "",
    },
    backend: {
      mode: "external_http",
      url: "http://127.0.0.1:8080",
      port: 8080,
      auto_start: true,
      command: "bun",
      args: ["src/tui/src/env-server-main.ts"],
      startup_timeout_ms: 5000,
    },
    tools: {
      hybrid: true,
      ohmy_pi: false,
      eval_ws_loopback: false,
      snippet_caps: ["IO", "FS", "Process"],
      delegated_timeout_ms: 30000,
      delegated_poll_ms: 100,
      delegated_timeout_slack_ms: 5000,
      edit_mode: "",
    },
    extensions: {
      order: [],
      strict: false,
    },
    verification: {},
  },
  null,
  2,
) + "\n";

export const EXTENSION_CONFIG_TEMPLATES: Record<string, string> = {
  compose: `[compose]
mode = "subagent"                        # AILANG_COMPOSITION_MODE
subagent_model = ""                      # AILANG_SUBAGENT_MODEL
max_attempts = 50                        # AILANG_SUBAGENT_MAX_ATTEMPTS
effect_guard = "1"                       # AILANG_COMPOSE_EFFECT_GUARD
certificate_template = false             # AILANG_COMPOSE_CERTIFICATE_TEMPLATE

[compose.authoring]
structured = true                        # AILANG_COMPOSE_STRUCTURED_AUTHORING
author_tools = false                     # AILANG_COMPOSE_AUTHOR_TOOLS
author_tools_budget = 25                 # AILANG_COMPOSE_AUTHOR_TOOLS_BUDGET
author_tools_max_bytes = 16384           # AILANG_COMPOSE_AUTHOR_TOOLS_MAX_BYTES
author_tools_max_turns = 24              # AILANG_COMPOSE_AUTHOR_TOOLS_MAX_TURNS
author_tools_deny_globs = ""             # AILANG_COMPOSE_AUTHOR_TOOLS_DENY_GLOBS
authoring_budget = 40                    # AILANG_COMPOSE_AUTHORING_BUDGET
fallback_after = 3                       # AILANG_COMPOSE_STRUCTURED_AUTHORING_FALLBACK_AFTER
min_observed_chars = 180                 # AILANG_COMPOSE_MIN_OBSERVED_CHARS
stdout_max_bytes = 4000                  # AILANG_COMPOSE_STDOUT_MAX_BYTES

[compose.claimcheck]
enabled = true                           # AILANG_COMPOSE_CLAIMCHECK
informalizer_model = ""                  # AILANG_COMPOSE_CLAIMCHECK_INFORMALIZER_MODEL
comparator_model = ""                    # AILANG_COMPOSE_CLAIMCHECK_COMPARATOR_MODEL
timeout_ms = 30000                       # AILANG_COMPOSE_CLAIMCHECK_TIMEOUT_MS
max_invocations = 10                     # AILANG_COMPOSE_CLAIMCHECK_MAX_INVOCATIONS
stdout_max_bytes = 4000                  # AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES
ledger_in_informalizer = true            # AILANG_COMPOSE_CLAIMCHECK_LEDGER_IN_INFORMALIZER
`,
  context_mode: `[context_mode]
bin = "context-mode"                     # CONTEXT_MODE_BIN
snapshot_key_prefix = "ctxmode:snapshot:" # CONTEXT_MODE_SNAPSHOT_KEY_PREFIX
`,
  exa_search: `[exa_search]
# API key is intentionally not configured here. Use EXA_API_KEY in the shell or .env.
`,
  omnigraph: `[omnigraph]
# Omnigraph currently has no env-var based config.
`,
};

export const EXTENSION_CONFIG_JSON_TEMPLATES: Record<string, string> = {
  compose: JSON.stringify(
    {
      compose: {
        mode: "subagent",
        subagent_model: "",
        max_attempts: 50,
        effect_guard: "1",
        certificate_template: false,
        authoring: {
          structured: true,
          author_tools: false,
          author_tools_budget: 25,
          author_tools_max_bytes: 16384,
          author_tools_max_turns: 24,
          author_tools_deny_globs: [],
          authoring_budget: 40,
          fallback_after: 3,
          min_observed_chars: 180,
          stdout_max_bytes: 4000,
        },
        claimcheck: {
          enabled: true,
          informalizer_model: "",
          comparator_model: "",
          timeout_ms: 30000,
          max_invocations: 10,
          stdout_max_bytes: 4000,
          ledger_in_informalizer: true,
        },
      },
    },
    null,
    2,
  ) + "\n",
  context_mode: JSON.stringify(
    {
      context_mode: {
        bin: "context-mode",
        timeout_ms: 25000,
        max_output_chars: 6000,
        snapshot_key_prefix: "ctxmode:snapshot:",
      },
    },
    null,
    2,
  ) + "\n",
  exa_search: JSON.stringify({ exa_search: { timeout_ms: 30000, max_output_chars: 8000 } }, null, 2) + "\n",
  omnigraph: JSON.stringify({ omnigraph: { timeout_ms: 30000 } }, null, 2) + "\n",
};

function getPathValue(root: unknown, dottedPath: string): unknown {
  let current = root;
  for (const part of dottedPath.split(".")) {
    if (typeof current !== "object" || current === null || Array.isArray(current)) {
      return undefined;
    }
    current = (current as Record<string, unknown>)[part];
  }
  return current;
}

function serializeValue(value: unknown, serializer?: Serialize): string | undefined {
  if (value === undefined || value === null) return undefined;
  if (serializer) return serializer(value);
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean" || typeof value === "bigint") {
    return String(value);
  }
  return undefined;
}

function applyConfigObject(
  config: unknown,
  mapping: ConfigMap,
  protectedKeys: Set<string>,
): void {
  for (const [configPath, entry] of Object.entries(mapping)) {
    if (protectedKeys.has(entry.env)) continue;
    const raw = getPathValue(config, configPath);
    const serialized = serializeValue(raw, entry.serialize);
    if (serialized === undefined || serialized === "") continue;
    process.env[entry.env] = serialized;
  }
}

function loadTomlFile(filePath: string, mapping: ConfigMap, protectedKeys: Set<string>): void {
  if (!fs.existsSync(filePath)) return;
  try {
    const parsed = parse(fs.readFileSync(filePath, "utf8"));
    applyConfigObject(parsed, mapping, protectedKeys);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(`[motoko-config] Failed to load ${filePath}: ${message}`);
  }
}

function activeExtensions(): string[] {
  return (process.env.CORE_EXT_ORDER ?? "")
    .split(",")
    .map((name) => name.trim())
    .filter((name) => name.length > 0);
}

export function activeProfile(): string {
  const profile = (process.env.MOTOKO_CONFIG ?? "").trim();
  return profile.length > 0 ? profile : "default";
}

export function resolveProfileDir(): string {
  const workdir = process.env.WORKDIR ?? process.cwd();
  const profile = activeProfile();
  const motokoDir = path.join(workdir, ".motoko");
  const profileDir = path.isAbsolute(profile)
    ? profile
    : path.join(motokoDir, "config", profile);
  const flatConfigPath = path.join(motokoDir, "config.toml");
  const profileConfigPath = path.join(profileDir, "config.toml");

  if (fs.existsSync(flatConfigPath) && !fs.existsSync(profileConfigPath)) {
    process.stderr.write(
      `[motoko-config] Deprecated flat config layout at ${motokoDir}; move TOML files to ${path.join(motokoDir, "config", "default")} or run 'make init-config ARGS=--migrate'.\n`,
    );
    return motokoDir;
  }

  return profileDir;
}

export function loadExtensionConfig(
  extName: string,
  dir: string = resolveProfileDir(),
  protectedKeys: Set<string> = new Set(),
): void {
  const mapping = EXTENSION_MAPS[extName];
  if (!mapping) return;
  loadTomlFile(path.join(dir, `${extName}.toml`), mapping, protectedKeys);
}

export function loadMotokoConfig(options: LoadMotokoConfigOptions = {}): void {
  const protectedKeys = options.protectedKeys ?? new Set<string>();
  const dir = resolveProfileDir();
  if (!fs.existsSync(dir)) return;
  loadTomlFile(path.join(dir, "config.toml"), CORE_MAP, protectedKeys);
  for (const extName of activeExtensions()) {
    loadExtensionConfig(extName, dir, protectedKeys);
  }
}
