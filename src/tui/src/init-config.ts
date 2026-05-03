import * as fs from "fs";
import * as path from "path";
import {
  CORE_CONFIG_JSON_TEMPLATE,
  CORE_CONFIG_TEMPLATE,
  EXTENSION_CONFIG_JSON_TEMPLATES,
  EXTENSION_CONFIG_TEMPLATES,
} from "./config.js";

function activeExtensions(all: boolean): string[] {
  if (all) return Object.keys(EXTENSION_CONFIG_TEMPLATES);
  return (process.env.CORE_EXT_ORDER ?? "")
    .split(",")
    .map((name) => name.trim())
    .filter((name) => name.length > 0 && EXTENSION_CONFIG_TEMPLATES[name] !== undefined);
}

function writeIfMissing(filePath: string, content: string): void {
  if (fs.existsSync(filePath)) {
    process.stderr.write(`[init-config] exists, not overwriting: ${filePath}\n`);
    return;
  }
  fs.writeFileSync(filePath, content, "utf8");
  process.stdout.write(`[init-config] wrote ${filePath}\n`);
}

function argValue(name: string, fallback: string): string {
  const index = process.argv.indexOf(name);
  if (index === -1) return fallback;
  const value = process.argv[index + 1];
  if (!value || value.startsWith("--")) return fallback;
  return value;
}

function migrateFlatConfig(): void {
  const motokoDir = path.join(process.cwd(), ".motoko");
  const flatConfig = path.join(motokoDir, "config.toml");
  if (!fs.existsSync(flatConfig)) {
    process.stdout.write(`[init-config] no flat config found at ${flatConfig}\n`);
    return;
  }

  const targetDir = path.join(motokoDir, "config", "default");
  fs.mkdirSync(targetDir, { recursive: true });

  for (const entry of fs.readdirSync(motokoDir)) {
    if (!entry.endsWith(".toml")) continue;
    const source = path.join(motokoDir, entry);
    const target = path.join(targetDir, entry);
    if (fs.existsSync(target)) {
      process.stderr.write(`[init-config] target exists, not moving: ${target}\n`);
      continue;
    }
    fs.renameSync(source, target);
    process.stdout.write(`[init-config] moved ${source} -> ${target}\n`);
  }
}

function main(): void {
  const all = process.argv.includes("--all");
  const migrate = process.argv.includes("--migrate");
  const withToml = process.argv.includes("--with-toml");
  const profile = argValue("--profile", "default");

  if (migrate) {
    migrateFlatConfig();
    return;
  }

  const configDir = path.join(process.cwd(), ".motoko", "config", profile);
  fs.mkdirSync(configDir, { recursive: true });

  writeIfMissing(path.join(configDir, "config.json"), CORE_CONFIG_JSON_TEMPLATE);
  if (withToml) {
    writeIfMissing(path.join(configDir, "config.toml"), CORE_CONFIG_TEMPLATE);
  }
  for (const extName of activeExtensions(all)) {
    const jsonTemplate = EXTENSION_CONFIG_JSON_TEMPLATES[extName];
    if (jsonTemplate !== undefined) {
      writeIfMissing(path.join(configDir, `${extName}.json`), jsonTemplate);
    }
    if (withToml) {
      writeIfMissing(path.join(configDir, `${extName}.toml`), EXTENSION_CONFIG_TEMPLATES[extName]);
    }
  }
}

main();
