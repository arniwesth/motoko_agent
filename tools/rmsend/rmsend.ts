#!/usr/bin/env bun
/**
 * rmsend — publish Markdown notes to a reMarkable 2 via the reMarkable Cloud.
 *
 *   md ──pandoc──> typst ──> pdf ──rmapi──> reMarkable Cloud ──sync──> tablet
 *
 * The cloud path is deliberate: it needs no USB cable and no network route to
 * the tablet, so it works unchanged from inside a dev container.
 *
 * Usage:
 *   rmsend <file|dir>...              Convert and upload (the default command)
 *   rmsend send <file|dir>...         The same thing, spelled out
 *   rmsend branch                     Send every .md this branch changes vs main
 *   rmsend install [--with-latex]     Install rmapi + pandoc + typst
 *   rmsend login                      Pair this machine with your account
 *   rmsend ls [dir]                   List a cloud folder
 *
 * Send options:
 *   --dir <path>           Target cloud folder (default: $RM_DIR or /Motoko). Created if absent.
 *   --format <fmt>         pdf (default) or epub. EPUB reflows and lets the tablet
 *                          pick the font size; PDF has fixed layout but annotates better.
 *   --converter <name>     auto (default, = typst) | typst | md2pdf.
 *                          md2pdf is the sibling tool: pandoc + XeLaTeX with mermaid
 *                          rendering and the cite-link/wide-table filters. Worth its
 *                          TeX dependency for documents that use those; typst — which
 *                          needs no external toolchain and is far faster — handles
 *                          everything else.
 *   --name <name>          Document name on the tablet (single input file only).
 *   --toc                  Include a table of contents.
 *   --replace              Delete an existing doc of the same name first. OFF by
 *                          default: rmapi has no in-place update, so replacing is a
 *                          delete plus a fresh upload and it discards any annotations
 *                          made on the tablet. Without it, re-sending makes a copy.
 *   --keep-out <dir>       Write the converted files to <dir> instead of a tempdir.
 *   --dry-run              Convert only; print what would be uploaded.
 *
 * Branch options: the send options above, plus
 *   --max <n>              Refuse to send more than n files (default: 20).
 *   --yes                  Send anyway, past --max.
 *
 * Page geometry: PDFs are A5 (148x210mm). The rM2 screen is 157x210mm, so A5
 * fills it with no pinch-zooming and leaves a thin side margin. Text is 11pt.
 *
 * Auth: the device token lives at $RMAPI_CONFIG, defaulting to
 * <repo>/.remarkable/rmapi.conf — inside the bind-mounted workspace, so a
 * container rebuild does not force a re-pair. It is gitignored; never commit it.
 */

import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { basename, dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir, tmpdir } from "node:os";

// ---------------------------------------------------------------------------
// Types & constants
// ---------------------------------------------------------------------------

type Format = "pdf" | "epub";
type Converter = "typst" | "md2pdf";

const VALID_FORMATS: Format[] = ["pdf", "epub"];
const VALID_CONVERTERS = ["auto", "typst", "md2pdf"];

const RMAPI_VERSION = "0.0.34";
const PANDOC_VERSION = "3.10.2";
const TYPST_VERSION = "0.15.1";

const PAIR_URL = "https://my.remarkable.com/device/browser/connect";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(SCRIPT_DIR, "..", "..");
const BIN_DIR = join(homedir(), ".local", "bin");
const MD2PDF = resolve(REPO_ROOT, "tools", "md2pdf", "md2pdf.ts");

interface SendOptions {
  dir: string;
  format: Format;
  converter: Converter | "auto";
  name: string | null;
  toc: boolean;
  replace: boolean;
  keepOut: string | null;
  dryRun: boolean;
}

// ---------------------------------------------------------------------------
// Process helpers
// ---------------------------------------------------------------------------

function die(msg: string): never {
  console.error(`rmsend: ${msg}`);
  process.exit(1);
}

/** ~/.local/bin holds the tools `rmsend install` drops; make sure it resolves. */
function childEnv(extra: Record<string, string> = {}): NodeJS.ProcessEnv {
  return { ...process.env, PATH: `${BIN_DIR}:${process.env.PATH ?? ""}`, ...extra };
}

function run(cmd: string, args: string[], env = childEnv()): { ok: boolean; stdout: string; stderr: string } {
  const r = spawnSync(cmd, args, { encoding: "utf8", env });
  return { ok: r.status === 0, stdout: r.stdout ?? "", stderr: r.stderr ?? "" };
}

/** For commands whose output (or prompt) belongs on the user's terminal. */
function runInherit(cmd: string, args: string[], env = childEnv()): boolean {
  return spawnSync(cmd, args, { stdio: "inherit", env }).status === 0;
}

function has(bin: string): boolean {
  return run("which", [bin]).ok;
}

function requireBin(bin: string): void {
  if (!has(bin)) die(`${bin} not found — run: bun tools/rmsend/rmsend.ts install`);
}

function humanSize(path: string): string {
  const bytes = statSync(path).size;
  return bytes >= 1024 * 1024 ? `${(bytes / 1024 / 1024).toFixed(1)}M` : `${Math.round(bytes / 1024)}K`;
}

// ---------------------------------------------------------------------------
// rmapi (reMarkable Cloud)
// ---------------------------------------------------------------------------

function configPath(): string {
  return process.env.RMAPI_CONFIG ?? join(REPO_ROOT, ".remarkable", "rmapi.conf");
}

function rmapiEnv(): NodeJS.ProcessEnv {
  return childEnv({ RMAPI_CONFIG: configPath() });
}

/**
 * `-ni` keeps rmapi from prompting for a pairing code: without a token it
 * would otherwise sit in an infinite prompt loop against a closed stdin.
 */
function rmapi(args: string[]): { ok: boolean; stdout: string; stderr: string } {
  return run("rmapi", ["-ni", ...args], rmapiEnv());
}

function requirePaired(): void {
  const cfg = configPath();
  if (!existsSync(cfg) || statSync(cfg).size === 0) {
    die(`not paired with reMarkable Cloud (no token at ${cfg}).\n  Run: bun tools/rmsend/rmsend.ts login`);
  }
}

/** `rmapi mkdir` errors on an existing folder, so probe with `ls` first. */
function ensureCloudDir(dir: string): void {
  if (dir === "/" || rmapi(["ls", dir]).ok) return;
  console.log(`  → creating cloud folder ${dir}`);
  const made = rmapi(["mkdir", dir]);
  if (!made.ok) die(`could not create ${dir}: ${made.stderr.trim()}`);
}

// ---------------------------------------------------------------------------
// Markdown → document
// ---------------------------------------------------------------------------

/** YAML front matter `title:`, else the first H1, else the file name. */
function titleOf(file: string, source: string): string {
  const fm = source.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (fm) {
    const t = fm[1].match(/^title:[ \t]*(.+)$/m);
    if (t) return t[1].trim().replace(/^["']|["']$/g, "");
  }
  const h1 = source.match(/^#[ \t]+(.+)$/m);
  if (h1) return h1[1].trim();
  return basename(file, extname(file));
}

/**
 * The tablet shows this as the document name. Strip the markdown emphasis
 * marks a heading carries and the one character the cloud API reads as a path
 * separator.
 */
function slugify(title: string): string {
  return title.replace(/\//g, "-").replace(/[`*]/g, "").replace(/\s+/g, " ").trim().slice(0, 100);
}

/**
 * When the title came from the document's own first H1, pandoc's title block
 * and that heading both render — the same words twice, on the same page. Drop
 * the heading and keep the title block, which carries the document metadata.
 */
function stripTitleHeading(source: string, title: string): string {
  const lines = source.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const h1 = lines[i].match(/^#[ \t]+(.+?)[ \t]*$/);
    if (h1) {
      if (h1[1] !== title) break; // a different heading: leave the body alone
      lines.splice(i, lines[i + 1]?.trim() === "" ? 2 : 1);
      break;
    }
    // Only the leading heading is a duplicate; stop at the first real content.
    if (lines[i].trim() !== "" && !/^(---|[a-zA-Z-]+:)/.test(lines[i])) break;
  }
  return lines.join("\n");
}

/**
 * Pandoc needs a blank line between a paragraph and a following list, or the
 * markers render as literal text. LLM-written markdown frequently omits it.
 * (The same normalization md2pdf applies before its own pandoc call.)
 */
function normalizeLists(source: string): string {
  const isList = (s: string) => /^\s*[*\-+]\s/.test(s) || /^\s*\d+\.\s/.test(s);
  const lines = source.split("\n");
  const out: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    if (i > 0 && isList(lines[i]) && lines[i - 1].trim() !== "" && !isList(lines[i - 1])) out.push("");
    out.push(lines[i]);
  }
  return out.join("\n");
}

/** Page setup for the typst engine. `margin` must reach the template as a YAML
 * map (it iterates margin/pairs), which -V cannot express — hence a file. */
function writePageMetadata(dir: string): string {
  const path = join(dir, "rmsend-page.yaml");
  writeFileSync(path, ["papersize: a5", "fontsize: 11pt", "margin:", "  x: 1.1cm", "  y: 1.4cm", ""].join("\n"));
  return path;
}

function convert(src: string, out: string, title: string, opts: SendOptions, workDir: string): void {
  if (opts.format === "pdf" && opts.converter === "md2pdf") {
    // md2pdf handles its own normalization, mermaid and filters; it only needs
    // to be told the page size, since it defaults to US Letter.
    const r = run("bun", [MD2PDF, src, out, "--paper", "a5", "--margin", "12mm", "--font-size", "11"]);
    if (!r.ok) throw new Error(r.stderr.trim() || "md2pdf failed");
    return;
  }

  // Feed pandoc a normalized copy. It lives in the work dir, so --resource-path
  // keeps relative image references resolving against the real source folder.
  const staged = join(workDir, `${slugify(title)}.src.md`);
  writeFileSync(staged, normalizeLists(stripTitleHeading(readFileSync(src, "utf8"), title)));

  const args = [
    staged,
    // -citations matters: without it pandoc reads a bare "@handle" as a citation
    // and the typst engine then aborts on the missing bibliography.
    "--from=markdown-citations+yaml_metadata_block+pipe_tables+task_lists+fenced_divs",
    "--standalone",
    "--metadata", `title=${title}`,
    "--resource-path", `.:${dirname(resolve(src))}`,
    "--lua-filter", join(SCRIPT_DIR, "strip-dead-anchors.lua"),
    "--output", out,
  ];
  if (opts.toc) args.push("--toc", "--toc-depth=3");
  if (opts.format === "pdf") args.push("--pdf-engine=typst", "--metadata-file", writePageMetadata(workDir));

  const r = run("pandoc", args);
  if (!r.ok) throw new Error(r.stderr.trim() || "pandoc failed");
}

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

/** A directory argument expands to every .md file beneath it. */
function expandInputs(paths: string[]): string[] {
  const out: string[] = [];
  const walk = (dir: string) => {
    for (const entry of readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const p = join(dir, entry.name);
      if (entry.isDirectory()) walk(p);
      else if (entry.isFile() && entry.name.endsWith(".md")) out.push(p);
    }
  };
  for (const p of paths) {
    if (!existsSync(p)) die(`no such file or directory: ${p}`);
    if (statSync(p).isDirectory()) walk(p);
    else out.push(p);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

function cmdSend(inputs: string[], opts: SendOptions): number {
  if (inputs.length === 0) die("no input files. Try: rmsend --help");
  const files = expandInputs(inputs);
  if (files.length === 0) die("no .md files found in the given paths");
  if (opts.name !== null && files.length > 1) die("--name only applies to a single input file");

  requireBin("pandoc");
  if (opts.format === "pdf" && opts.converter === "typst") requireBin("typst");
  if (opts.format === "pdf" && opts.converter === "md2pdf") {
    if (!existsSync(MD2PDF)) die("tools/md2pdf/md2pdf.ts not found");
    if (!has("xelatex")) die("xelatex not found — install it with `rmsend install --with-latex`, or use --converter typst");
  }
  if (!opts.dryRun) {
    requireBin("rmapi");
    requirePaired();
    ensureCloudDir(opts.dir);
  }

  const workDir = opts.keepOut !== null ? resolve(opts.keepOut) : mkdtempSync(join(tmpdir(), "rmsend-"));
  mkdirSync(workDir, { recursive: true });

  let failed = 0;
  try {
    for (const src of files) {
      const title = opts.name ?? titleOf(src, readFileSync(src, "utf8"));
      const docName = slugify(title);
      const out = join(workDir, `${docName}.${opts.format}`);

      console.log(`  → ${src}`);
      try {
        convert(src, out, title, opts, workDir);
      } catch (err) {
        console.error(`  ✗ ${src}: ${err instanceof Error ? err.message : String(err)}`);
        failed++;
        continue;
      }
      const via = opts.format === "pdf" ? `via ${opts.converter}` : "epub";
      console.log(`    converted: ${basename(out)} (${humanSize(out)}, ${via})`);

      if (opts.dryRun) {
        console.log(`    would upload to ${opts.dir}/`);
        continue;
      }
      if (opts.replace) rmapi(["rm", `${opts.dir}/${docName}`]);

      const put = rmapi(["put", out, opts.dir]);
      if (put.ok) console.log(`    ✓ uploaded to ${opts.dir}/${docName}`);
      else {
        console.error(`  ✗ ${src}: upload failed: ${put.stderr.trim()}`);
        failed++;
      }
    }
  } finally {
    if (opts.keepOut === null) rmSync(workDir, { recursive: true, force: true });
  }

  if (opts.keepOut !== null) console.log(`\nConverted files kept in ${resolve(opts.keepOut)}`);
  if (failed > 0) {
    console.error(`\n${failed} file(s) failed.`);
    return 1;
  }
  if (!opts.dryRun) {
    console.log("\nDone. The tablet picks these up on its next cloud sync (pull down on the home screen for it now).");
  }
  return 0;
}

/**
 * Every .md this branch adds or changes vs main, plus uncommitted ones.
 * Guarded by --max: a long-lived branch can differ by hundreds of documents,
 * and pruning those off a tablet is manual work.
 */
function cmdBranch(opts: SendOptions, max: number, yes: boolean): number {
  const base = run("git", ["merge-base", "HEAD", "main"]);
  if (!base.ok) die("could not find a merge base with main");
  const committed = run("git", ["diff", "--name-only", "--diff-filter=d", `${base.stdout.trim()}...HEAD`, "--", "*.md"]);
  const working = run("git", ["status", "--porcelain", "--", "*.md"]);

  const files = [
    ...committed.stdout.split("\n"),
    ...working.stdout.split("\n").map((l) => l.slice(3).trim()),
  ]
    .map((f) => f.trim())
    .filter((f) => f.length > 0 && existsSync(f));

  const unique = [...new Set(files)].sort();
  if (unique.length === 0) {
    console.log("No changed markdown on this branch.");
    return 0;
  }
  if (unique.length > max && !yes) {
    console.error(`${unique.length} changed markdown files vs main (limit --max ${max}).`);
    console.error("Narrow it down, or re-run with --yes.");
    return 1;
  }
  console.log(`Sending ${unique.length} file(s).`);
  return cmdSend(unique, opts);
}

function cmdInstall(force: boolean, withLatex: boolean): number {
  if (process.platform !== "linux") {
    die(
      "automatic install covers Linux only.\n" +
        "  macOS: brew install pandoc typst, and grab rmapi from\n" +
        `  https://github.com/ddvk/rmapi/releases/tag/v${RMAPI_VERSION}`,
    );
  }
  const arch = process.arch === "arm64" ? "arm64" : "amd64";
  const typstTriple = process.arch === "arm64" ? "aarch64-unknown-linux-musl" : "x86_64-unknown-linux-musl";

  mkdirSync(BIN_DIR, { recursive: true });
  const work = mkdtempSync(join(tmpdir(), "rmsend-install-"));

  // Each entry: the binary, its archive, and where the binary sits inside it.
  const targets = [
    {
      bin: "rmapi",
      version: RMAPI_VERSION,
      url: `https://github.com/ddvk/rmapi/releases/download/v${RMAPI_VERSION}/rmapi-linux-${arch}.tar.gz`,
      archive: "rmapi.tar.gz",
      tarFlags: ["-xzf"],
      inner: "rmapi",
    },
    {
      bin: "pandoc",
      version: PANDOC_VERSION,
      url: `https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-linux-${arch}.tar.gz`,
      archive: "pandoc.tar.gz",
      tarFlags: ["-xzf"],
      inner: `pandoc-${PANDOC_VERSION}/bin/pandoc`,
    },
    {
      bin: "typst",
      version: TYPST_VERSION,
      url: `https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-${typstTriple}.tar.xz`,
      archive: "typst.tar.xz",
      tarFlags: ["-xJf"],
      inner: `typst-${typstTriple}/typst`,
    },
  ];

  try {
    for (const t of targets) {
      if (!force && has(t.bin)) {
        console.log(`  ✓ ${t.bin} already installed (${run("which", [t.bin]).stdout.trim()})`);
        continue;
      }
      console.log(`  → installing ${t.bin} ${t.version} (${arch})`);
      const archive = join(work, t.archive);
      if (!run("curl", ["-fsSL", "-o", archive, t.url]).ok) die(`download failed: ${t.url}`);
      if (!run("tar", [...t.tarFlags, archive, "-C", work, t.inner]).ok) die(`could not extract ${t.inner}`);
      if (!run("install", ["-m", "0755", join(work, t.inner), join(BIN_DIR, t.bin)]).ok) die(`could not install ${t.bin}`);
    }
  } finally {
    rmSync(work, { recursive: true, force: true });
  }

  if (withLatex) {
    if (has("xelatex") && !force) {
      console.log(`  ✓ xelatex already installed (${run("which", ["xelatex"]).stdout.trim()})`);
    } else {
      console.log("  → installing texlive-xetex + fonts + librsvg (for tools/md2pdf; this is slow)");
      runInherit("sudo", ["apt-get", "update", "-qq"]);
      if (!runInherit("sudo", ["apt-get", "install", "-y", "-qq", "texlive-xetex", "texlive-fonts-recommended", "librsvg2-bin"])) {
        die("apt-get install failed");
      }
    }
  }

  console.log("\nInstalled:");
  for (const bin of ["rmapi", "pandoc", "typst", ...(withLatex ? ["xelatex"] : [])]) {
    console.log(`  ${bin.padEnd(8)} ${run("which", [bin]).stdout.trim() || "MISSING"}`);
  }
  if (!(process.env.PATH ?? "").split(":").includes(BIN_DIR)) {
    console.log(`\nNOTE: ${BIN_DIR} is not on PATH — add it to your shell profile.`);
  }
  console.log(`\nNext, pair with your reMarkable account (one time):\n  bun tools/rmsend/rmsend.ts login`);
  return 0;
}

function cmdLogin(): number {
  requireBin("rmapi");
  const cfg = configPath();
  mkdirSync(dirname(cfg), { recursive: true });
  console.log(`Open ${PAIR_URL} and paste the 8-character code.`);
  // No -ni here: this is the one call that must be allowed to prompt.
  if (!runInherit("rmapi", ["ls", "/"], rmapiEnv())) return 1;
  console.log(`\nPaired. Token stored at ${cfg}`);
  return 0;
}

function cmdLs(dir: string): number {
  requireBin("rmapi");
  requirePaired();
  const r = rmapi(["ls", dir]);
  process.stdout.write(r.stdout);
  if (!r.ok) {
    console.error(r.stderr.trim());
    return 1;
  }
  return 0;
}

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const USAGE = `
Usage: rmsend <file|dir>... [options]
       rmsend <command> [args] [options]

Commands:
  send <file|dir>...     Convert and upload (default; may be omitted)
  branch                 Send every .md this branch changes vs main
  install                Install rmapi + pandoc + typst into ~/.local/bin
  login                  Pair this machine with your reMarkable account
  ls [dir]               List a cloud folder

Send options:
  --dir <path>           Target cloud folder (default: $RM_DIR or /Motoko)
  --format <fmt>         ${VALID_FORMATS.join(" | ")} (default: pdf)
  --converter <name>     ${VALID_CONVERTERS.join(" | ")} (default: auto, = typst)
  --name <name>          Document name on the tablet (single input only)
  --toc                  Include a table of contents
  --replace              Delete an existing doc of the same name first
                         (discards annotations made on the tablet)
  --keep-out <dir>       Keep converted files in <dir>
  --dry-run              Convert only; print what would be uploaded

Branch options:
  --max <n>              Refuse to send more than n files (default: 20)
  --yes                  Send anyway, past --max

Install options:
  --force                Reinstall even if already present
  --with-latex           Also install XeLaTeX + librsvg, for --converter md2pdf
`.trim();

function main(argv: string[]): number {
  if (argv.length === 0 || argv[0] === "-h" || argv[0] === "--help") {
    console.log(USAGE);
    return argv.length === 0 ? 1 : 0;
  }

  const commands = ["send", "branch", "install", "login", "ls"];
  const command = commands.includes(argv[0]) ? argv.shift()! : "send";

  const positional: string[] = [];
  const opts: SendOptions = {
    dir: process.env.RM_DIR ?? "/Motoko",
    format: "pdf",
    converter: "auto",
    name: null,
    toc: false,
    replace: false,
    keepOut: null,
    dryRun: false,
  };
  let max = 20;
  let yes = false;
  let force = false;
  let withLatex = false;

  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    const next = (): string => {
      const val = argv[++i];
      if (val === undefined || val.startsWith("--")) die(`${flag} requires a value`);
      return val;
    };
    switch (flag) {
      case "--dir": opts.dir = next(); break;
      case "--format": {
        const val = next();
        if (!(VALID_FORMATS as string[]).includes(val)) die(`--format must be one of: ${VALID_FORMATS.join(", ")}`);
        opts.format = val as Format;
        break;
      }
      case "--converter": {
        const val = next();
        if (!VALID_CONVERTERS.includes(val)) die(`--converter must be one of: ${VALID_CONVERTERS.join(", ")}`);
        opts.converter = val as Converter | "auto";
        break;
      }
      case "--name": opts.name = next(); break;
      case "--toc": opts.toc = true; break;
      case "--replace": opts.replace = true; break;
      case "--keep-out": opts.keepOut = next(); break;
      case "--dry-run": opts.dryRun = true; break;
      case "--max": {
        const val = Number(next());
        if (!Number.isInteger(val) || val < 1) die("--max must be a positive integer");
        max = val;
        break;
      }
      case "--yes": yes = true; break;
      case "--force": force = true; break;
      case "--with-latex": withLatex = true; break;
      case "-h":
      case "--help": console.log(USAGE); return 0;
      default:
        if (flag.startsWith("-")) die(`unknown option: ${flag}`);
        positional.push(flag);
    }
  }

  // typst is the default even where a TeX install makes md2pdf available: it is
  // far faster and needs no external toolchain. Ask for md2pdf when a document
  // needs what it adds — mermaid diagrams, [cite: N] links, wide tables.
  if (opts.converter === "auto") opts.converter = "typst";

  switch (command) {
    case "send": return cmdSend(positional, opts);
    case "branch": return cmdBranch(opts, max, yes);
    case "install": return cmdInstall(force, withLatex);
    case "login": return cmdLogin();
    case "ls": return cmdLs(positional[0] ?? opts.dir);
    default: die(`unknown command: ${command}`);
  }
}

process.exit(main(process.argv.slice(2)));
