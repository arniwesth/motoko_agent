// tui/src/profiles.ts
//
// Profile discovery for motoko. Scans .motoko/config/ for available profiles
// and returns their metadata (name, model, extensions).

import * as fs from "fs";
import * as path from "path";

export interface ProfileInfo {
  name: string;
  model: string;
  extensions: string[];
}

/**
 * Scan for available motoko profiles by looking for config.json files
 * under .motoko/config/<profile>/. Returns profile names sorted alphabetically.
 */
export function fetchAvailableProfiles(workdir: string = process.cwd()): ProfileInfo[] {
  const profilesDir = path.join(workdir, ".motoko", "config");
  const results: ProfileInfo[] = [];

  if (!fs.existsSync(profilesDir)) {
    return results;
  }

  const entries = fs.readdirSync(profilesDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const profileName = entry.name;
    const configPath = path.join(profilesDir, profileName, "config.json");

    let model = "unknown";
    let extensions: string[] = [];

    if (fs.existsSync(configPath)) {
      try {
        const raw = fs.readFileSync(configPath, "utf8");
        const parsed = JSON.parse(raw) as Record<string, unknown>;

        // Extract model from agent.model
        const agent = parsed.agent as Record<string, unknown> | undefined;
        if (agent && typeof agent.model === "string") {
          model = agent.model;
        }

        // Extract extensions from extensions.order
        const ext = parsed.extensions as Record<string, unknown> | undefined;
        if (ext && Array.isArray(ext.order)) {
          extensions = ext.order.filter((e): e is string => typeof e === "string");
        }
      } catch {
        // Invalid JSON — use defaults
      }
    }

    results.push({ name: profileName, model, extensions });
  }

  return results.sort((a, b) => a.name.localeCompare(b.name));
}

/**
 * Get the current active profile name from MOTOKO_CONFIG env var
 * or return "default" if unset.
 */
export function currentProfile(): string {
  return process.env.MOTOKO_CONFIG ?? "default";
}
