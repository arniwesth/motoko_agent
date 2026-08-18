#!/usr/bin/env bun
/**
 * md2pdf — convert a Markdown file to PDF via pandoc + XeLaTeX.
 *
 * Usage:
 *   md2pdf <input.md> [output.pdf] [options]
 *
 * If <output.pdf> is omitted the PDF is written alongside the input file
 * with the same basename.
 *
 * Options:
 *   --engine <name>        TeX engine: xelatex (default), lualatex, pdflatex
 *   --paper <name>         Page size: letter (default), a4, a5, a6, b5, legal, executive
 *   --margin <size>        Page margin (default: 1in). Any LaTeX length: 2cm, 15mm…
 *   --font-size <pt>       Font size in pt (default: 11)
 *   --mainfont <name>      Main font name, passed to fontspec (xelatex/lualatex only)
 *   --template <file>      Custom pandoc LaTeX template file
 *   --lua-filter <file>    Additional Lua filter passed to pandoc (repeatable)
 *   --no-bundled-filters   Skip automatically applied bundled Lua filters
 *   --keep-tex             Write the intermediate .tex file next to the output PDF
 *   --open                 Open the PDF after writing (macOS: open, Linux: xdg-open)
 *
 * Mermaid:
 *   ```mermaid fenced blocks are rendered to PNG via beautiful-mermaid + rsvg-convert
 *   and embedded as images. Requires rsvg-convert (librsvg2-bin).
 *
 * Bundled Lua filters (applied automatically unless --no-bundled-filters is set):
 *   cite-links.lua             Converts [cite: N, M] to superscript hyperlinks to anchored sources.
 *   narrow-first-col.lua      Pins "#" index columns to 5% width in Pros/Cons tables.
 *   landscape-wide-tables.lua Rotates tables with ≥5 columns to landscape.
 */

import { existsSync, readFileSync, mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { resolve, dirname, basename, extname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";

// ---------------------------------------------------------------------------
// Types & constants
// ---------------------------------------------------------------------------

type Engine = "xelatex" | "lualatex" | "pdflatex";
const VALID_ENGINES: Engine[] = ["xelatex", "lualatex", "pdflatex"];

// Sizes pandoc's LaTeX template understands as `<name>paper` geometry options.
const VALID_PAPERS = ["letter", "legal", "executive", "a4", "a5", "a6", "b5"];

interface Args {
  input: string;        // resolved absolute path
  output: string;       // resolved absolute path
  engine: Engine;
  paper: string;        // resolved: always set (from flag, style preset, or default)
  margin: string;       // resolved: always set (from flag, style preset, or default)
  fontSize: number;     // resolved: always set
  mainfont: string | null;
  template: string | null;   // resolved absolute path, or null
  luaFilters: string[];      // resolved absolute paths, in application order
  mermaidTheme: string;      // theme name passed to beautiful-mermaid
  keepTex: boolean;
  open: boolean;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function die(msg: string): never {
  console.error(msg);
  process.exit(1);
}

/** Run a command synchronously; returns stdout, stderr, and exit status. */
function run(cmd: string, args: string[]): { ok: boolean; stderr: string } {
  const result = spawnSync(cmd, args, { encoding: "utf8" });
  return { ok: result.status === 0, stderr: result.stderr ?? "" };
}

/** Verify a binary is on PATH and die with an actionable install hint if not. */
function requireBin(name: string, hint: string): void {
  const { status } = spawnSync("which", [name], { encoding: "utf8" });
  if (status !== 0) die(`"${name}" not found on PATH.\n${hint}`);
}

/**
 * Build the pandoc flag array that is common to both the direct-to-PDF path
 * and the keep-tex path (which writes .tex first, then invokes the engine).
 * Does NOT include -o / output path — callers append that themselves.
 */
function buildPandocFlags(a: Args): string[] {
  const flags: string[] = [
    a.input,
    "--pdf-engine", a.engine,
    "-V", `papersize=${a.paper}`,
    "-V", `geometry:margin=${a.margin}`,
    "-V", `fontsize=${a.fontSize}pt`,
  ];

  // fontspec font selection requires xelatex or lualatex; skip + warn for pdflatex.
  if (a.mainfont !== null) {
    if (a.engine === "pdflatex") {
      console.error("Warning: --mainfont is ignored with pdflatex (fontspec requires xelatex or lualatex).");
    } else {
      flags.push("-V", `mainfont=${a.mainfont}`);
    }
  }

  if (a.template !== null) {
    flags.push("--template", a.template);
  }

  for (const f of a.luaFilters) {
    flags.push("--lua-filter", f);
  }

  return flags;
}

// ---------------------------------------------------------------------------
// Mermaid preprocessing
// ---------------------------------------------------------------------------

/**
 * Scan `source` for ```mermaid fenced blocks. For each one:
 *   1. Render to SVG via beautiful-mermaid (same library as mmd2svg).
 *   2. Convert SVG → PNG via rsvg-convert (XeLaTeX embeds PNG natively).
 *   3. Write the PNG to `tmpDir`.
 *   4. Replace the fenced block with a plain Markdown image reference.
 *
 * Returns the rewritten markdown string. If no mermaid blocks exist the
 * original string is returned unchanged and `tmpDir` is never created.
 *
 * Throws on render or conversion failure so the caller can die() cleanly.
 */
async function renderMermaidBlocks(
  source: string,
  tmpDir: string,
  theme: string,
): Promise<string> {
  // Matches ```mermaid ... ``` blocks, non-greedy, across newlines.
  const FENCE = /^```mermaid\s*\n([\s\S]*?)\n```/gm;
  const matches = [...source.matchAll(FENCE)];
  if (matches.length === 0) return source;

  requireBin(
    "rsvg-convert",
    "Install rsvg-convert:\n  Debian/Ubuntu: sudo apt install librsvg2-bin\n  macOS:         brew install librsvg",
  );

  // Lazy-import so the module is only loaded when there are diagrams to render.
  const { renderMermaidSVG, THEMES } = await import("beautiful-mermaid");

  // Use the same default theme as mmd2svg.
  const DEFAULT_THEME = "monokai-charcoal-hc";
  const CUSTOM_THEMES: Record<string, object> = {
    "monokai-charcoal-hc": {
      bg: "#000000", fg: "#FFFFFF", accent: "#A6E22E",
      line: "#66D9EF", muted: "#8f8f8f", surface: "#000c18", border: "#8f8f8f",
    },
  };

  const resolvedTheme = theme === "default"
    ? CUSTOM_THEMES[DEFAULT_THEME]
    : (THEMES[theme] ?? CUSTOM_THEMES[theme]);
  if (!resolvedTheme) die(`Unknown mermaid theme "${theme}".`);

  let result = source;
  let idx = 0;

  for (const match of matches) {
    const diagramSrc = match[1];
    if (!diagramSrc.trim()) continue;

    // Render SVG.
    let svg: string;
    try {
      svg = renderMermaidSVG(diagramSrc, resolvedTheme as never);
    } catch (err) {
      throw new Error(`Mermaid render failed: ${err instanceof Error ? err.message : String(err)}`);
    }

    // Convert SVG → PNG via rsvg-convert.
    const pngPath = join(tmpDir, `mermaid-${idx}.png`);
    const svgBuf = Buffer.from(svg, "utf8");
    const conv = spawnSync("rsvg-convert", ["-o", pngPath], {
      input: svgBuf,
      maxBuffer: 32 * 1024 * 1024,
    });
    if (conv.status !== 0) {
      throw new Error(`rsvg-convert failed: ${conv.stderr?.toString() ?? "unknown error"}`);
    }

    // Replace the fenced block with a Markdown image.
    // Use an empty alt string; caption can be added via pandoc figure syntax if desired.
    result = result.replace(match[0], `![](${pngPath})`);
    idx++;
  }

  return result;
}

// ---------------------------------------------------------------------------
// Arg parsing — no external deps
// ---------------------------------------------------------------------------

const USAGE = `
Usage: md2pdf <input.md> [output.pdf] [options]

  input.md               Path to a Markdown source file.
  output.pdf             Destination PDF. Defaults to <input>.pdf in the same directory.

  --engine <name>        TeX engine: xelatex (default), lualatex, pdflatex
  --paper <name>         Page size: ${VALID_PAPERS.join(", ")} (default: letter)
  --margin <size>        Page margin passed to the geometry package (default: 1in)
  --font-size <pt>       Base font size in pt (default: 11)
  --mainfont <name>      Main font for fontspec (xelatex/lualatex only)
  --template <file>      Custom pandoc LaTeX template file
  --lua-filter <file>    Additional Lua filter (repeatable)
  --no-bundled-filters   Skip automatically applied bundled Lua filters
  --mermaid-theme <name> Theme for Mermaid diagrams (default: monokai-charcoal-hc)
  --keep-tex             Preserve the intermediate .tex file next to the PDF
  --open                 Open the PDF after writing (uses "open" on macOS, "xdg-open" on Linux)
`.trim();

function parseArgs(argv: string[]): Args {
  const positional: string[] = [];
  let engine: Engine = "xelatex";
  let paper: string | null = null;
  let margin: string | null = null;
  let fontSize: number | null = null;
  let mainfont: string | null = null;
  let templateArg: string | null = null;
  let styleArg: string | null = null;
  const luaFilterArgs: string[] = [];
  let noBundledFilters = false;
  let mermaidTheme = "default"; // "default" resolved inside renderMermaidBlocks
  let keepTex = false;
  let open = false;

  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];

    // Consume the next token as the value for a flag; die if missing.
    const next = (): string => {
      const val = argv[++i];
      if (!val || val.startsWith("-")) die(`${flag} requires a value`);
      return val;
    };

    switch (flag) {
      case "--engine": {
        const val = next();
        if (!(VALID_ENGINES as string[]).includes(val))
          die(`--engine must be one of: ${VALID_ENGINES.join(", ")}`);
        engine = val as Engine;
        break;
      }
      case "--paper": {
        const val = next().toLowerCase();
        if (!VALID_PAPERS.includes(val))
          die(`--paper must be one of: ${VALID_PAPERS.join(", ")}`);
        paper = val;
        break;
      }
      case "--margin":
        margin = next();
        break;
      case "--font-size": {
        const val = next();
        const n = Number(val);
        if (!Number.isInteger(n) || n < 6 || n > 72)
          die("--font-size must be an integer between 6 and 72");
        fontSize = n;
        break;
      }
      case "--mainfont":
        mainfont = next();
        break;
      case "--template":
        templateArg = next();
        break;
      case "--lua-filter":
        luaFilterArgs.push(next());
        break;
      case "--no-bundled-filters":
        noBundledFilters = true;
        break;
      case "--style":
        styleArg = next();
        break;
      case "--mermaid-theme":
        mermaidTheme = next();
        break;
      case "--keep-tex":
        keepTex = true;
        break;
      case "--open":
        open = true;
        break;
      case "--help":
      case "-h":
        console.log(USAGE);
        process.exit(0);
        break;
      default:
        if (flag.startsWith("-")) die(`Unknown flag: ${flag}\n\n${USAGE}`);
        positional.push(flag);
    }
  }

  if (positional.length === 0) die(USAGE);

  const inputRaw = positional[0];
  const outputRaw = positional[1] ?? null;

  const input = resolve(process.cwd(), inputRaw);
  const output =
    outputRaw !== null
      ? resolve(process.cwd(), outputRaw)
      : resolve(dirname(input), basename(input, extname(input)) + ".pdf");

  // Apply style preset. Explicit flags (--template, --margin, --font-size) win over preset.
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const STYLES: Record<string, { template: string; margin: string; fontSize: number }> = {
    arxiv: {
      template: resolve(scriptDir, "templates", "arxiv.tex"),
      margin: "1.25in",
      fontSize: 10,
    },
  };

  if (styleArg !== null) {
    const preset = STYLES[styleArg];
    if (!preset) die(`Unknown style "${styleArg}". Available: ${Object.keys(STYLES).join(", ")}`);
    if (templateArg === null) templateArg = preset.template;  // --template overrides --style
    if (margin === null)      margin = preset.margin;
    if (fontSize === null)    fontSize = preset.fontSize;
  }

  // Apply defaults for anything still unset. "letter" preserves the page size
  // LaTeX produced before --paper existed.
  if (paper === null)    paper = "letter";
  if (margin === null)   margin = "1in";
  if (fontSize === null) fontSize = 11;

  const template =
    templateArg !== null ? resolve(process.cwd(), templateArg) : null;

  // Resolve user-supplied Lua filters relative to cwd.
  const luaFilters: string[] = luaFilterArgs.map((f) => resolve(process.cwd(), f));

  // Auto-inject bundled filters that live alongside this script, unless suppressed.
  // Bundled filters run before user-supplied filters so user filters can override.
  if (!noBundledFilters) {
    const scriptDir = dirname(fileURLToPath(import.meta.url));
    const bundled = ["cite-links.lua", "narrow-first-col.lua", "landscape-wide-tables.lua"];
    for (const name of bundled) {
      const p = resolve(scriptDir, name);
      if (existsSync(p)) luaFilters.unshift(p);
    }
  }

  return { input, output, engine, paper: paper!, margin: margin!, fontSize: fontSize!, mainfont, template, luaFilters, mermaidTheme, keepTex, open };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const args = parseArgs(process.argv.slice(2));

// Validate dependencies before any I/O so errors are immediate and actionable.
requireBin(
  "pandoc",
  "Install pandoc:\n  Debian/Ubuntu: sudo apt install pandoc\n  macOS:         brew install pandoc",
);
requireBin(
  args.engine,
  `Install a TeX distribution that provides ${args.engine}:\n  Debian/Ubuntu: sudo apt install texlive-xetex texlive-fonts-recommended\n  macOS:         brew install --cask mactex`,
);

if (!existsSync(args.input)) die(`Cannot find "${args.input}"`);
if (args.template !== null && !existsSync(args.template))
  die(`Template file not found: "${args.template}"`);

// ---------------------------------------------------------------------------
// Mermaid: preprocess fenced blocks before handing off to pandoc.
// ---------------------------------------------------------------------------

// Read source now so we can inspect it for mermaid blocks.
let markdownSource = readFileSync(args.input, "utf8");

// tmpDir is created only if mermaid blocks are found; cleaned up after pandoc.
let mermaidTmpDir: string | null = null;

// renderMermaidBlocks is async (dynamic import of beautiful-mermaid); hoist
// the top-level await via an immediately-invoked async wrapper.
await (async () => {
  if (!/^```mermaid/m.test(markdownSource)) return; // fast path: no diagrams

  mermaidTmpDir = mkdtempSync(join(tmpdir(), "md2pdf-mermaid-"));
  try {
    markdownSource = await renderMermaidBlocks(markdownSource, mermaidTmpDir, args.mermaidTheme);
  } catch (err) {
    rmSync(mermaidTmpDir, { recursive: true, force: true });
    die(err instanceof Error ? err.message : String(err));
  }
})();

// ---------------------------------------------------------------------------
// Markdown normalization: ensure blank lines before list starts.
// Pandoc requires a blank line between a paragraph and a list; without it the
// list markers are rendered as literal text. AI-generated markdown frequently
// omits this blank line.
// ---------------------------------------------------------------------------

{
  const lines = markdownSource.split("\n");
  const patched: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const isList = /^\s*[\*\-\+]\s/.test(line) || /^\s*\d+\.\s/.test(line);
    if (isList && i > 0) {
      const prev = lines[i - 1];
      const prevNonBlank = prev.trim().length > 0;
      const prevIsList = /^\s*[\*\-\+]\s/.test(prev) || /^\s*\d+\.\s/.test(prev);
      if (prevNonBlank && !prevIsList) {
        patched.push("");
      }
    }
    patched.push(line);
  }
  const normalized = patched.join("\n");
  if (normalized !== markdownSource) {
    markdownSource = normalized;
  }
}

// ---------------------------------------------------------------------------
// Build pandoc flags.
// When mermaid blocks were preprocessed we feed patched markdown via stdin
// (using "-" as the input path) so pandoc sees the rewritten content.
// Image paths in the rewritten markdown are absolute, so the working
// directory doesn't matter.
// ---------------------------------------------------------------------------

// Swap the input path for "-" (stdin) when content was preprocessed.
const patchedInput = markdownSource !== readFileSync(args.input, "utf8");
const pandocInput = patchedInput ? "-" : args.input;

// buildPandocFlags uses args.input; override it for the stdin case.
const baseFlags = buildPandocFlags({ ...args, input: pandocInput });

// Helper: run pandoc, feeding stdin when we have patched markdown.
function runPandoc(extraFlags: string[]): { ok: boolean; stderr: string } {
  const allArgs = [...baseFlags, ...extraFlags];
  if (!patchedInput) return run("pandoc", allArgs);
  const result = spawnSync("pandoc", allArgs, {
    input: markdownSource,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  return { ok: result.status === 0, stderr: result.stderr ?? "" };
}

try {
  if (args.keepTex) {
    // Two-step: pandoc → .tex, then engine → .pdf.
    // This gives the caller both artifacts and makes TeX errors easier to diagnose.
    const texPath = args.output.replace(/\.pdf$/i, "") + ".tex";

    const texResult = runPandoc(["-s", "-o", texPath]);
    if (!texResult.ok) die(`pandoc failed while writing .tex:\n${texResult.stderr}`);
    process.stderr.write(`\x1b[32mTeX written to ${texPath}\x1b[0m\n`);

    // Compile the .tex with the chosen engine.
    // -output-directory keeps auxiliary files (.aux, .log) out of cwd.
    const engineResult = run(args.engine, [
      "-interaction=nonstopmode",
      `-output-directory=${dirname(args.output)}`,
      texPath,
    ]);
    if (!engineResult.ok) die(`${args.engine} failed:\n${engineResult.stderr}`);
  } else {
    // Single-step: pandoc drives the engine internally.
    const result = runPandoc(["-o", args.output]);
    if (!result.ok) die(`pandoc failed:\n${result.stderr}`);
  }
} finally {
  // Clean up temp PNG files regardless of success or failure.
  if (mermaidTmpDir !== null) {
    rmSync(mermaidTmpDir, { recursive: true, force: true });
  }
}

process.stderr.write(`\x1b[32mWritten to ${args.output}\x1b[0m\n`);

if (args.open) {
  // Best-effort; ignore failures (the PDF was written successfully).
  const opener = process.platform === "darwin" ? "open" : "xdg-open";
  run(opener, [args.output]);
}