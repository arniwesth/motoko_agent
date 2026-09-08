#!/usr/bin/env bun
/**
 * mmd2svg — render a Mermaid source file to SVG.
 *
 * Usage:
 *   mmd2svg <input.mmd> [output.svg] [--theme <name>]
 *
 * If <output.svg> is omitted the SVG is written to stdout.
 * If <output.svg> is omitted the SVG is written to stdout.
 * --theme defaults to "zinc-light". Accepts all 15 built-in beautiful-mermaid
 * themes plus any custom themes defined in CUSTOM_THEMES below.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { renderMermaidSVG, THEMES } from "beautiful-mermaid";

import type { DiagramColors } from "beautiful-mermaid";

// ---------------------------------------------------------------------------
// Custom themes — extend this map to add new themes.
// Keys must not collide with the built-in THEMES keys.
// ---------------------------------------------------------------------------

const CUSTOM_THEMES: Record<string, DiagramColors> = {
  // Source: https://github.com/74th/vscode-monokaicharcoal
  // Colors derived from Monokai-Charcoal-gray.json (high contrast variant).
  "monokai-charcoal-hc": {
    bg:      "#000000", // editor.background
    fg:      "#FFFFFF", // editor.foreground
    accent:  "#A6E22E", // entity.name.function — Monokai green
    line:    "#66D9EF", // storage.type — cyan
    muted:   "#8f8f8f", // editorLineNumber.foreground
    surface: "#000c18", // editor.lineHighlight / selection
    border:  "#8f8f8f", // editor borders (alpha stripped)
  },
};

// ---------------------------------------------------------------------------
// Arg parsing — intentionally minimal; no external deps.
// ---------------------------------------------------------------------------

const DEFAULT_THEME = "monokai-charcoal-hc"

interface Args {
  input: string;
  output: string | null; // null → stdout
  theme: string;
}

function parseArgs(argv: string[]): Args {
  // argv is process.argv.slice(2) — positional + flag pairs only
  const positional: string[] = [];
  let theme = DEFAULT_THEME;

  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--theme") {
      const next = argv[++i];
      if (!next || next.startsWith("-")) {
        die("--theme requires a value");
      }
      theme = next;
    } else if (argv[i].startsWith("--")) {
      die(`Unknown flag: ${argv[i]}`);
    } else {
      positional.push(argv[i]);
    }
  }

  if (positional.length === 0) {
    die(USAGE);
  }

  return {
    input: positional[0],
    output: positional[1] ?? null,
    theme,
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function die(msg: string): never {
  console.error(msg);
  process.exit(1);
}

const USAGE = `
Usage: mmd2svg <input.mmd> [output.svg] [--theme <name>]

  input.mmd   Path to a Mermaid source file.
  output.svg  Destination SVG file. Omit to write to stdout.
  --theme     Built-in or custom theme name (default: ${DEFAULT_THEME}).
              Built-in: zinc-light, zinc-dark, tokyo-night, tokyo-night-storm,
              tokyo-night-light, catppuccin-mocha, catppuccin-latte,
              nord, nord-light, dracula, github-light, github-dark,
              solarized-light, solarized-dark, one-dark
              Custom:   monokai-charcoal-hc
`.trim();

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const args = parseArgs(process.argv.slice(2));

// Validate theme before doing any I/O so the error is immediate.
const themeOptions = THEMES[args.theme] ?? CUSTOM_THEMES[args.theme];
if (!themeOptions) {
  die(
    `Unknown theme "${args.theme}". Run mmd2svg --help or omit --theme to use the default.`
  );
}

// Read source — resolve relative to cwd so the caller's working directory is
// the frame of reference, not the script location.
let source: string;
try {
  source = readFileSync(resolve(process.cwd(), args.input), "utf8");
} catch (err: unknown) {
  die(
    `Cannot read "${args.input}": ${err instanceof Error ? err.message : String(err)}`
  );
}

if (source.trim().length === 0) {
  die(`"${args.input}" is empty — nothing to render.`);
}

// Render — renderMermaidSVG throws a descriptive error on parse failure.
let svg: string;
try {
  svg = renderMermaidSVG(source, themeOptions);
} catch (err: unknown) {
  die(
    `Render failed: ${err instanceof Error ? err.message : String(err)}`
  );
}

// Write output.
if (args.output === null) {
  process.stdout.write(svg);
} else {
  const dest = resolve(process.cwd(), args.output);
  try {
    writeFileSync(dest, svg, "utf8");
    process.stderr.write(`\x1b[32mWritten to ${dest}\x1b[0m\n`); // green; stderr so it doesn't pollute piped SVG
  } catch (err: unknown) {
    die(
      `Cannot write "${dest}": ${err instanceof Error ? err.message : String(err)}`
    );
  }
}
