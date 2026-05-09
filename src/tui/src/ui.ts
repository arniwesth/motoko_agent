// tui/src/ui.ts
//
// pi-tui terminal UI for Motoko.
//
// Layout (top to bottom):
//   1. History pane  — Box containing Text/Markdown children; grows in height
//   2. Status bar    — Text showing step count + model
  // 3. Command input — Editor (not Input) for slash-command tab-complete
//
// Styling approach: pi-tui components carry no colour options.  We apply
// ANSI via chalk's bgFn parameter where colouring is useful; plain Text is
// left unstyled so it inherits the terminal default.
//
// Model selection:
//   /model <name>   → switchModel() immediately
//   /model          → showModelPicker() opens a SelectList overlay
//
// Overlay lifecycle: showOverlay() returns an OverlayHandle; we store it and
// call handle.hide() on cancel.  A new handle is created each time the
// picker is shown.

import chalk from "chalk";
import { TUI, Text, Markdown, Editor, type EditorTheme, Box, SelectList, ProcessTerminal, type OverlayHandle, type SelectItem, type MarkdownTheme, matchesKey } from "@mariozechner/pi-tui";
import type { AgentEvent } from "./runtime-process.js";
import type { DelegatedCall, DelegatedResult, NativeToolResult } from "./runtime-process.js";
import type { RuntimeProcess } from "./runtime-process.js";
import { resolveDelegatedExec } from "./runtime-process.js";
import { fetchDynamicModelsFromEnv } from "./models.js";
import { type SlashCommandHandlerCtx, parseSlashCommand, createCommandAutocompleteProvider } from "./commands.js";
import { canonicalToolIdentity, extractToolPlanSnapshot } from "./tool-plan-parser.js";
import { normalizeJsonLang, segmentStreamMarkdown, trimSegmentsForLiveRender } from "./stream-markdown.js";
import { highlightJsonLines } from "./json-highlight.js";
import { execSync } from "child_process";
// NOTE: The ASCII-art banner is printed unconditionally in main() before the 
// TUI starts here — ANSI escapes in Text children corrupt the layout system.

type TsState = {
  inBlockComment: boolean;
};

type PyState = {
  inTripleQuote: '"""' | "'''" | null;
};

type AilangState = {
  inEffectBlock: boolean;
  awaitEffectBrace: boolean;
};

type DiffInnerLang = "ts" | "py" | "ail" | "sh" | null;

type DiffState = {
  innerLang: DiffInnerLang;
  tsState: TsState;
  pyState: PyState;
  ailangState: AilangState;
  oldLine: number | null;
  newLine: number | null;
  inHunk: boolean;
};

const TS_KEYWORDS = new Set<string>([
  "as", "async", "await", "break", "case", "catch", "class", "const", "continue",
  "debugger", "declare", "default", "delete", "do", "else", "enum", "export",
  "extends", "finally", "for", "from", "function", "if", "implements", "import",
  "in", "instanceof", "interface", "let", "new", "null", "package", "private",
  "protected", "public", "readonly", "return", "satisfies", "static", "super",
  "switch", "this", "throw", "try", "type", "typeof", "undefined", "var", "void",
  "while", "with", "yield",
]);

const TS_BUILTINS = new Set<string>([
  "Array", "Boolean", "Date", "Error", "JSON", "Map", "Math", "Number", "Object",
  "Promise", "RegExp", "Set", "String", "Symbol", "console", "process",
]);

const PY_KEYWORDS = new Set<string>([
  "and", "as", "assert", "async", "await", "break", "class", "continue", "def",
  "del", "elif", "else", "except", "False", "finally", "for", "from", "global",
  "if", "import", "in", "is", "lambda", "None", "nonlocal", "not", "or", "pass",
  "raise", "return", "True", "try", "while", "with", "yield", "match", "case",
]);

const PY_BUILTINS = new Set<string>([
  "dict", "float", "int", "len", "list", "print", "set", "str", "tuple",
]);

export const AILANG_RESERVED_KEYWORDS = [
  "if", "then", "else", "match", "with", "select", "timeout",
  "func", "pure", "let", "letrec", "in",
  "type", "class", "instance", "forall", "exists", "deriving",
  "module", "import", "export", "extern", "as",
  "test", "tests", "property", "properties", "assert",
  "requires", "ensures", "invariant",
  "spawn", "parallel", "channel", "send", "recv",
  "true", "false", "and", "or", "not",
] as const;

const AILANG_KEYWORDS = new Set<string>(AILANG_RESERVED_KEYWORDS);
const AILANG_EFFECTS = new Set<string>([
  "AI", "Debug", "Env", "FS", "IO", "Net", "Process", "SharedMem", "Stream",
]);
const AILANG_PRIMITIVE_TYPES = new Set<string>(["int", "float", "bool", "string", "char", "unit"]);
const AILANG_STDLIB_TYPES = new Set<string>(["Option", "Result", "List", "Tuple", "Array", "Json"]);
const AILANG_PRELUDE_FUNCS = new Set<string>(["print", "println", "show", "intToFloat", "floatToInt"]);

const SHELL_KEYWORDS = new Set<string>([
  "if", "then", "else", "fi", "for", "while", "do", "done", "case", "esac",
  "function", "in",
]);

const EXT_TO_LANG: Record<string, DiffInnerLang> = {
  ts: "ts",
  tsx: "ts",
  js: "ts",
  jsx: "ts",
  mjs: "ts",
  cjs: "ts",
  py: "py",
  ail: "ail",
  sh: "sh",
  bash: "sh",
  zsh: "sh",
};

const DIFF_ADD_BG = (text: string): string => chalk.bgRgb(20, 64, 44)(text);
const DIFF_DEL_BG = (text: string): string => chalk.bgRgb(72, 34, 34)(text);

function isIdentStart(ch: string): boolean {
  return /[A-Za-z_$]/.test(ch);
}

function isIdentPart(ch: string): boolean {
  return /[A-Za-z0-9_$]/.test(ch);
}

function isPyIdentStart(ch: string): boolean {
  return /[A-Za-z_]/.test(ch);
}

function isPyIdentPart(ch: string): boolean {
  return /[A-Za-z0-9_]/.test(ch);
}

function isAilangIdentStart(ch: string): boolean {
  return /[A-Za-z_]/.test(ch);
}

function isAilangIdentPart(ch: string): boolean {
  return /[A-Za-z0-9_]/.test(ch);
}

function isAilangConstructor(word: string): boolean {
  return /^[A-Z][A-Za-z0-9_]*$/.test(word);
}

function highlightTsLine(line: string, state: TsState): string {
  let out = "";
  let i = 0;
  while (i < line.length) {
    const ch = line[i];
    const next = i + 1 < line.length ? line[i + 1] : "";

    if (state.inBlockComment) {
      const end = line.indexOf("*/", i);
      if (end === -1) return out + chalk.gray(line.slice(i));
      out += chalk.gray(line.slice(i, end + 2));
      i = end + 2;
      state.inBlockComment = false;
      continue;
    }

    if (ch === "/" && next === "/") return out + chalk.gray(line.slice(i));

    if (ch === "/" && next === "*") {
      const end = line.indexOf("*/", i + 2);
      if (end === -1) {
        state.inBlockComment = true;
        return out + chalk.gray(line.slice(i));
      }
      out += chalk.gray(line.slice(i, end + 2));
      i = end + 2;
      continue;
    }

    if (ch === '"' || ch === "'" || ch === "`") {
      const quote = ch;
      let j = i + 1;
      let escaped = false;
      while (j < line.length) {
        const c = line[j];
        if (escaped) {
          escaped = false;
          j += 1;
          continue;
        }
        if (c === "\\") {
          escaped = true;
          j += 1;
          continue;
        }
        if (c === quote) {
          j += 1;
          break;
        }
        j += 1;
      }
      out += chalk.green(line.slice(i, j));
      i = j;
      continue;
    }

    if (isIdentStart(ch)) {
      let j = i + 1;
      while (j < line.length && isIdentPart(line[j])) j += 1;
      const word = line.slice(i, j);
      if (TS_KEYWORDS.has(word)) out += chalk.blueBright(word);
      else if (TS_BUILTINS.has(word)) out += chalk.cyanBright(word);
      else out += word;
      i = j;
      continue;
    }

    if (/[0-9]/.test(ch)) {
      let j = i + 1;
      while (j < line.length && /[0-9A-Fa-f_xobn.]/.test(line[j])) j += 1;
      out += chalk.magentaBright(line.slice(i, j));
      i = j;
      continue;
    }

    out += ch;
    i += 1;
  }
  return out;
}

function highlightPyLine(line: string, state: PyState): string {
  let out = "";
  let i = 0;
  while (i < line.length) {
    if (state.inTripleQuote) {
      const q = state.inTripleQuote;
      const end = line.indexOf(q, i);
      if (end === -1) return out + chalk.green(line.slice(i));
      out += chalk.green(line.slice(i, end + 3));
      i = end + 3;
      state.inTripleQuote = null;
      continue;
    }

    const ch = line[i];
    const next3 = line.slice(i, i + 3);
    if (ch === "#") return out + chalk.gray(line.slice(i));

    if (next3 === '"""' || next3 === "'''") {
      const quote = next3 as '"""' | "'''";
      const end = line.indexOf(quote, i + 3);
      if (end === -1) {
        state.inTripleQuote = quote;
        return out + chalk.green(line.slice(i));
      }
      out += chalk.green(line.slice(i, end + 3));
      i = end + 3;
      continue;
    }

    if (ch === '"' || ch === "'") {
      const quote = ch;
      let j = i + 1;
      let escaped = false;
      while (j < line.length) {
        const c = line[j];
        if (escaped) {
          escaped = false;
          j += 1;
          continue;
        }
        if (c === "\\") {
          escaped = true;
          j += 1;
          continue;
        }
        if (c === quote) {
          j += 1;
          break;
        }
        j += 1;
      }
      out += chalk.green(line.slice(i, j));
      i = j;
      continue;
    }

    if (isPyIdentStart(ch)) {
      let j = i + 1;
      while (j < line.length && isPyIdentPart(line[j])) j += 1;
      const word = line.slice(i, j);
      if (PY_KEYWORDS.has(word)) out += chalk.blueBright(word);
      else if (PY_BUILTINS.has(word)) out += chalk.cyanBright(word);
      else out += word;
      i = j;
      continue;
    }

    if (/[0-9]/.test(ch)) {
      let j = i + 1;
      while (j < line.length && /[0-9A-Fa-f_xob.]/.test(line[j])) j += 1;
      out += chalk.magentaBright(line.slice(i, j));
      i = j;
      continue;
    }

    out += ch;
    i += 1;
  }
  return out;
}

function highlightAilangLine(line: string, state: AilangState): string {
  let out = "";
  let i = 0;
  const ops = ["<-", "->", "=>", "::", "++", "&&", "||", "==", "!=", "<=", ">=", "<<", ">>", "**"];
  while (i < line.length) {
    const ch = line[i];
    const next = i + 1 < line.length ? line[i + 1] : "";

    if ((ch === "-" && next === "-") || (ch === "/" && next === "/")) return out + chalk.gray(line.slice(i));

    if (ch === '"' || ch === "'") {
      const quote = ch;
      let j = i + 1;
      let escaped = false;
      while (j < line.length) {
        const c = line[j];
        if (escaped) {
          escaped = false;
          j += 1;
          continue;
        }
        if (c === "\\") {
          escaped = true;
          j += 1;
          continue;
        }
        if (c === quote) {
          j += 1;
          break;
        }
        j += 1;
      }
      out += chalk.green(line.slice(i, j));
      i = j;
      continue;
    }

    let opMatched = false;
    for (const op of ops) {
      if (line.startsWith(op, i)) {
        out += chalk.yellow(op);
        i += op.length;
        opMatched = true;
        break;
      }
    }
    if (opMatched) continue;

    if (ch === "!" || ch === "|" || ch === "\\") {
      out += chalk.yellow(ch);
      if (ch === "!") state.awaitEffectBrace = true;
      i += 1;
      continue;
    }

    if (ch === "(" && next === ")") {
      out += chalk.magentaBright("()");
      i += 2;
      continue;
    }

    if (ch === "{") {
      out += ch;
      if (state.awaitEffectBrace) {
        state.inEffectBlock = true;
        state.awaitEffectBrace = false;
      }
      i += 1;
      continue;
    }

    if (ch === "}") {
      out += ch;
      state.inEffectBlock = false;
      i += 1;
      continue;
    }

    if (/\s/.test(ch)) {
      out += ch;
      i += 1;
      continue;
    }

    if (isAilangIdentStart(ch)) {
      let j = i + 1;
      while (j < line.length && isAilangIdentPart(line[j])) j += 1;
      const word = line.slice(i, j);
      if (AILANG_KEYWORDS.has(word)) out += chalk.blueBright(word);
      else if (state.inEffectBlock && AILANG_EFFECTS.has(word)) out += chalk.cyanBright(word);
      else if (AILANG_PRIMITIVE_TYPES.has(word)) out += chalk.cyanBright(word);
      else if (AILANG_PRELUDE_FUNCS.has(word)) out += chalk.yellowBright(word);
      else if (word.startsWith("_")) out += chalk.yellow(word);
      else if (AILANG_STDLIB_TYPES.has(word)) out += chalk.cyan(word);
      else if (isAilangConstructor(word)) out += chalk.cyan(word);
      else out += word;
      i = j;
      continue;
    }

    if (/[0-9]/.test(ch)) {
      let j = i + 1;
      while (j < line.length && /[0-9.]/.test(line[j])) j += 1;
      out += chalk.magentaBright(line.slice(i, j));
      i = j;
      continue;
    }

    out += ch;
    i += 1;
  }
  return out;
}

function highlightShellLine(line: string): string {
  let out = "";
  let i = 0;
  let commandStyled = false;
  while (i < line.length) {
    const ch = line[i];
    if (ch === "#") return out + chalk.gray(line.slice(i));
    if (ch === "$" && line[i + 1] === "{") {
      const end = line.indexOf("}", i + 2);
      if (end !== -1) {
        out += chalk.cyanBright(line.slice(i, end + 1));
        i = end + 1;
        continue;
      }
    }
    if (ch === "$") {
      const m = line.slice(i).match(/^\$[A-Za-z_][A-Za-z0-9_]*/);
      if (m) {
        out += chalk.cyanBright(m[0]);
        i += m[0].length;
        continue;
      }
    }
    if (/[A-Za-z_]/.test(ch)) {
      let j = i + 1;
      while (j < line.length && /[A-Za-z0-9_/-]/.test(line[j])) j += 1;
      const word = line.slice(i, j);
      if (SHELL_KEYWORDS.has(word)) out += chalk.blueBright(word);
      else if (!commandStyled && out.trim().length === 0) {
        out += chalk.yellowBright(word);
        commandStyled = true;
      } else out += word;
      i = j;
      continue;
    }
    out += ch;
    i += 1;
  }
  return out;
}

function getStylePrefix(styleFn: (text: string) => string): string {
  const sentinel = "\u0000";
  const styled = styleFn(sentinel);
  const idx = styled.indexOf(sentinel);
  return idx >= 0 ? styled.slice(0, idx) : "";
}

function applyBackgroundPreserveAnsi(line: string, bgStyle: (text: string) => string): string {
  const prefix = getStylePrefix(bgStyle);
  if (!prefix) return bgStyle(line);
  const withReappliedBg = line.replace(/\x1b\[0m/g, `\x1b[0m${prefix}`);
  return bgStyle(withReappliedBg);
}

function inferDiffLangFromHeader(headerLine: string): DiffInnerLang {
  const pathRaw = headerLine.slice(4).trim();
  if (!pathRaw || pathRaw === "/dev/null") return null;
  const path = pathRaw.replace(/^[ab]\//, "").split("\t")[0];
  const ext = path.includes(".") ? path.slice(path.lastIndexOf(".") + 1).toLowerCase() : "";
  return EXT_TO_LANG[ext] ?? null;
}

function isDiffFileHeaderLine(line: string, prefix: "--- " | "+++ "): boolean {
  if (!line.startsWith(prefix)) return false;
  const pathRaw = line.slice(4).trim();
  if (!pathRaw) return false;
  const path = pathRaw.split("\t")[0];
  return path === "/dev/null" || path.startsWith("a/") || path.startsWith("b/");
}

function formatDiffGutter(oldLine: number | null, newLine: number | null): string {
  const oldText = oldLine === null ? " ".repeat(4) : String(oldLine).padStart(4, " ");
  const newText = newLine === null ? " ".repeat(4) : String(newLine).padStart(4, " ");
  return chalk.dim(`${oldText} ${newText} │ `);
}

function highlightInnerDiffLine(content: string, state: DiffState): string {
  switch (state.innerLang) {
    case "ts":
      return highlightTsLine(content, state.tsState);
    case "py":
      return highlightPyLine(content, state.pyState);
    case "ail":
      return highlightAilangLine(content, state.ailangState);
    case "sh":
      return highlightShellLine(content);
    default:
      return content;
  }
}

function resetDiffInnerState(state: DiffState): void {
  state.tsState = { inBlockComment: false };
  state.pyState = { inTripleQuote: null };
  state.ailangState = { inEffectBlock: false, awaitEffectBrace: false };
}

function highlightDiffLine(line: string, state: DiffState): string {
  if (line.startsWith("diff ") || line.startsWith("index ") || line.startsWith("new file mode") || line.startsWith("deleted file mode")) {
    state.inHunk = false;
    state.oldLine = null;
    state.newLine = null;
    return formatDiffGutter(null, null) + chalk.dim(line);
  }
  if (!state.inHunk && isDiffFileHeaderLine(line, "+++ ")) {
    const inferred = inferDiffLangFromHeader(line);
    if (inferred !== null) state.innerLang = inferred;
    state.inHunk = false;
    state.oldLine = null;
    state.newLine = null;
    resetDiffInnerState(state);
    return formatDiffGutter(null, null) + chalk.greenBright.bold(line);
  }
  if (!state.inHunk && isDiffFileHeaderLine(line, "--- ")) {
    const inferred = inferDiffLangFromHeader(line);
    if (inferred !== null) state.innerLang = inferred;
    state.inHunk = false;
    state.oldLine = null;
    state.newLine = null;
    resetDiffInnerState(state);
    return formatDiffGutter(null, null) + chalk.redBright.bold(line);
  }
  if (line.startsWith("@@")) {
    state.inHunk = true;
    const m = line.match(/^@@\s+-(\d+)(?:,\d+)?\s+\+(\d+)(?:,\d+)?\s+@@/);
    if (m) {
      state.oldLine = Number(m[1]);
      state.newLine = Number(m[2]);
    } else {
      state.oldLine = null;
      state.newLine = null;
    }
    return formatDiffGutter(null, null) + chalk.cyanBright(line);
  }
  if (line.startsWith("+")) {
    const old = null;
    const neu = state.newLine;
    if (state.newLine !== null) state.newLine += 1;
    const inner = highlightInnerDiffLine(line.slice(1), state);
    const prefixed = `${chalk.greenBright.bold("+")}${inner}`;
    return formatDiffGutter(old, neu) + applyBackgroundPreserveAnsi(prefixed, DIFF_ADD_BG);
  }
  if (line.startsWith("-")) {
    const old = state.oldLine;
    const neu = null;
    if (state.oldLine !== null) state.oldLine += 1;
    const inner = highlightInnerDiffLine(line.slice(1), state);
    const prefixed = `${chalk.redBright.bold("-")}${inner}`;
    return formatDiffGutter(old, neu) + applyBackgroundPreserveAnsi(prefixed, DIFF_DEL_BG);
  }
  if (line.startsWith(" ")) {
    const old = state.oldLine;
    const neu = state.newLine;
    if (state.oldLine !== null) state.oldLine += 1;
    if (state.newLine !== null) state.newLine += 1;
    const inner = highlightInnerDiffLine(line.slice(1), state);
    return formatDiffGutter(old, neu) + ` ${inner}`;
  }
  return formatDiffGutter(null, null) + line;
}

export function highlightCodeLines(code: string, lang?: string): string[] {
  const lines = code.split("\n");
  const normalized = (lang ?? "").trim().toLowerCase();
  if (["ts", "tsx", "typescript", "js", "jsx", "javascript", "mjs", "cjs"].includes(normalized)) {
    const state: TsState = { inBlockComment: false };
    return lines.map((line) => highlightTsLine(line, state));
  }
  if (["py", "python"].includes(normalized)) {
    const state: PyState = { inTripleQuote: null };
    return lines.map((line) => highlightPyLine(line, state));
  }
  if (["ail", "ailang"].includes(normalized)) {
    const state: AilangState = { inEffectBlock: false, awaitEffectBrace: false };
    return lines.map((line) => highlightAilangLine(line, state));
  }
  if (["bash", "sh", "zsh", "shell"].includes(normalized)) {
    return lines.map((line) => highlightShellLine(line));
  }
  if (["json", "jsonc", "application/json"].includes(normalized)) {
    return highlightJsonLines(code);
  }
  if (["diff", "patch"].includes(normalized)) {
    const state: DiffState = {
      innerLang: null,
      tsState: { inBlockComment: false },
      pyState: { inTripleQuote: null },
      ailangState: { inEffectBlock: false, awaitEffectBrace: false },
      oldLine: null,
      newLine: null,
      inHunk: false,
    };
    return lines.map((line) => highlightDiffLine(line, state));
  }
  return lines.map((line) => chalk.dim(line));
}

// ---------------------------------------------------------------------------
// Minimal markdown theme: headings in bold, code in dim, rest unstyled.
// ---------------------------------------------------------------------------
const MINIMAL_THEME: MarkdownTheme = {
  heading: (t) => chalk.bold(t),
  link: (t) => chalk.underline(t),
  linkUrl: (t) => chalk.dim(t),
  code: (t) => chalk.dim(t),
  codeBlock: (t) => chalk.dim(t),
  codeBlockBorder: (t) => chalk.dim(t),
  quote: (t) => t,
  quoteBorder: (t) => chalk.dim(t),
  hr: (t) => chalk.dim(t),
  listBullet: (t) => t,
  bold: (t) => chalk.bold(t),
  italic: (t) => chalk.italic(t),
  strikethrough: (t) => chalk.strikethrough(t),
  underline: (t) => chalk.underline(t),
  highlightCode: (code, lang) => highlightCodeLines(code, lang),
};

// Minimal SelectList theme: highlight selected item in cyan bold.
const SELECT_THEME = {
  selectedPrefix: (t: string) => chalk.cyanBright(t),
  selectedText: (t: string) => chalk.cyanBright.bold(t),
  description: (t: string) => chalk.dim(t),
  scrollInfo: (t: string) => chalk.dim(t),
  noMatch: (t: string) => chalk.dim(t),
};

// Minimal Editor theme: border colour + nested SelectList theme.
const EDITOR_SELECT_THEME = {
  selectedPrefix: (t: string) => chalk.cyanBright(t),
  selectedText: (t: string) => chalk.cyanBright.bold(t),
  description: (t: string) => chalk.dim(t),
  scrollInfo: (t: string) => chalk.dim(t),
  noMatch: (t: string) => chalk.dim(t),
};
const EDITOR_THEME: EditorTheme = {
  borderColor: (t: string) => chalk.dim(t),
  selectList: EDITOR_SELECT_THEME,
} as const;

// ---------------------------------------------------------------------------
// Helper: wrap a string with an ANSI styling function for Text's bgFn.
// bgFn receives the rendered text per-line; we use it as a foreground style.
// ---------------------------------------------------------------------------
function styledText(content: string, style: (s: string) => string): Text {
  return new Text(content, 0, 0, style);
}

function plainText(content: string): Text {
  return new Text(content, 0, 0);
}

function stripLikelyInlineToolBlob(text: string): string {
  const m = text.match(/^\s*json\s*\{/i);
  if (!m || m.index === undefined) return text;
  const start = m.index + m[0].toLowerCase().indexOf("json");
  const tail = text.slice(start);
  const looksLikeToolBlob =
    tail.includes("\"tool_calls\"") &&
    tail.includes("\"tool\"") &&
    tail.includes("\"id\"") &&
    tail.length >= 400;
  if (!looksLikeToolBlob) return text;
  return text.slice(0, start).trimEnd();
}

function isInternalComposeStream(streamId: string): boolean {
  const id = (streamId ?? "").trim();
  return id.startsWith("compose-");
}

type InternalComposeStreamPhase =
  | "author"
  | "summary"
  | "claimcheck_informalize"
  | "claimcheck_compare";

interface InternalComposeStreamInfo {
  phase: InternalComposeStreamPhase;
  composeId: string;
  attempt: number;
}

function stripRetrySuffix(streamTail: string): string {
  return streamTail.replace(/-r\d+$/, "");
}

function parseInternalComposeStream(streamId: string): InternalComposeStreamInfo | undefined {
  const id = (streamId ?? "").trim();
  const candidates: Array<{ prefix: string; phase: InternalComposeStreamPhase }> = [
    { prefix: "compose-author-", phase: "author" },
    { prefix: "compose-summary-", phase: "summary" },
    { prefix: "compose-claimcheck-informalize-", phase: "claimcheck_informalize" },
    { prefix: "compose-claimcheck-compare-repair-", phase: "claimcheck_compare" },
    { prefix: "compose-claimcheck-compare-", phase: "claimcheck_compare" },
  ];
  for (const candidate of candidates) {
    if (!id.startsWith(candidate.prefix)) continue;
    const rawTail = id.slice(candidate.prefix.length);
    const tail = stripRetrySuffix(rawTail);
    const sep = tail.lastIndexOf("-");
    if (sep <= 0 || sep >= tail.length - 1) return undefined;
    const composeId = tail.slice(0, sep);
    const attempt = Number.parseInt(tail.slice(sep + 1), 10);
    if (!Number.isFinite(attempt) || attempt <= 0) return undefined;
    return { phase: candidate.phase, composeId, attempt };
  }
  return undefined;
}

function mergeSnapshotWithStream(current: string, incoming: string): string {
  if (incoming.trim() === "") return current;
  if (current.trim() === "") return incoming;
  if (incoming === current) return current;
  if (incoming.startsWith(current)) return incoming;
  if (current.startsWith(incoming)) return current;
  if (incoming.endsWith(current)) return incoming;
  if (current.endsWith(incoming)) return current;
  return current + incoming;
}

function formatTimestamp(now: Date = new Date()): string {
  const hh = String(now.getHours()).padStart(2, "0");
  const mm = String(now.getMinutes()).padStart(2, "0");
  const ss = String(now.getSeconds()).padStart(2, "0");
  const mmm = String(now.getMilliseconds()).padStart(3, "0");
  return `${hh}:${mm}:${ss}.${mmm}`;
}

export type RunState = "idle" | "thinking" | "tools_wait" | "tools_run" | "error";
type HintPhase = "thinking" | "tools";
type ToolRowStatus = "queued" | "running" | "done" | "failed";
type PlannedToolStatus = "planned" | "running" | "done" | "error" | "planned_unexecuted" | "runtime_only" | "filtered";
type StatusLineIcon = "queued" | "running" | "done" | "failed" | "warning" | "info" | "background";

const STREAM_TEXT_MAX_BYTES = 128 * 1024;
const TOOL_PLAN_PARSE_MAX_BYTES = 64 * 1024;
const STREAM_VISIBLE_MAX_CHARS = 6000;
const STREAM_RENDER_THROTTLE_MS = 50;
const TOOL_JSON_PREVIEW_MIN_CHARS = 1200;
const TOOL_JSON_PREVIEW_MIN_LINES = 18;

export interface StatusLineFields {
  icon: StatusLineIcon;
  title: string;
  description?: string;
  badge?: string;
  meta?: string[];
}

export interface ToolRenderCtx {
  describeToolCall: (call: DelegatedCall) => string;
}

export interface ToolRenderer {
  renderCall: (call: DelegatedCall, ctx: ToolRenderCtx) => string;
}

interface ToolBatchState {
  total: number;
  running: number;
  done: number;
  failed: number;
  active: boolean;
  seen: Set<string>;
}

type ToolRowRenderStatus = ToolRowStatus | "warning";
type ToolRowKind = "default" | "readfile_group_child";

export interface ToolRowDetails {
  status: ToolRowRenderStatus;
  stdout: string;
  stderr: string;
  truncated: boolean;
  exitCode?: number;
}

interface ToolDetailRenderOptions {
  toolName?: string;
}

interface ToolGroupState {
  requestId: string;
  groupId: string;
  toolFamily: "ReadFile";
  headerRow: Text;
  childKeys: string[];
  total: number;
}

interface ComposeAttemptState {
  attempt: number;
  snippet: string;
  authorDelta: string;
  authorError?: string;
  authorToolCalls?: string[];
  authorToolResults?: string[];
  authorLedgerSnapshot?: string;
  authorStreamSeen?: boolean;
  checkPassed?: boolean;
  checkErrors?: string;
  retryReason?: string;
  stdout?: string;
  stderr?: string;
  exitCode?: number;
  claimcheckInformalizeDelta?: string;
  claimcheckInformalization?: string;
  claimcheckCompareDelta?: string;
  claimcheckVerdict?: "confirmed" | "disputed" | "vacuous" | "surprising_restriction" | "inconclusive";
  claimcheckConfidence?: "high" | "low";
  claimcheckReason?: string;
}

interface ComposeCardState {
  composeId: string;
  step: number;
  intent: string;
  intentKind?: string;
  claimcheckEnabled?: boolean;
  model: string;
  maxAttempts: number;
  startedAtMs: number;
  finishedAtMs?: number;
  attempts: Map<number, ComposeAttemptState>;
  summaryDelta: string;
  summary: string;
  resultExitCode?: number;
  resultAttempts?: number;
  resultTruncated?: boolean;
  telemetryJson?: string;
  expanded: boolean;
  headerRow: Text;
  bodyRow: Text;
}

interface PlannedToolEntry {
  step: number;
  identity: string;
  meta: string;
  status: PlannedToolStatus;
  row: Text;
  detailRow: Text;
  requestIds: Set<string>;
}

type ToolEnvelopeConfidence = "confident_strict" | "confident_heuristic" | "not_confident";

export interface ToolBatchCounters {
  total: number;
  running: number;
  done: number;
  failed: number;
  seen: Set<string>;
}

const GENERIC_TOOL_RENDERER: ToolRenderer = {
  renderCall: (call, ctx) => ctx.describeToolCall(call),
};

// Tool-specific renderers are registered here as phases add special behavior.
// Keep fallback deterministic by always routing missing/throwing renderers
// through renderToolCallMetaWithFallback().
const TOOL_RENDERERS: Record<string, ToolRenderer> = {};
const TOOL_STDOUT_PREVIEW_LINES = 8;
const TOOL_STDERR_PREVIEW_LINES = 4;
const TOOL_DIFF_PREVIEW_LINES = 40;
const TOOL_RENDER_COALESCE_MS = 50;
const STAMP_PREFIX_WIDTH = 15; // "[hh:mm:ss.mmm] "

const STATUS_ICON_TAG: Record<ToolRowStatus, StatusLineIcon> = {
  queued: "queued",
  running: "running",
  done: "done",
  failed: "failed",
};

export function formatStatusLine(fields: StatusLineFields, statusTag?: ToolRowStatus): string {
  const parts: string[] = [];
  if (statusTag) parts.push(`[${statusTag}]`);
  parts.push(fields.title);
  if (fields.description) parts.push(fields.description);
  if (fields.meta && fields.meta.length > 0) parts.push(...fields.meta);
  if (fields.badge) parts.push(fields.badge);
  return parts.join(" ");
}

function toolHeaderFields(requestId: string, description: string): StatusLineFields {
  return {
    icon: "background",
    title: `[tools] ${requestId}`,
    description,
  };
}

function toolRowFields(status: ToolRowStatus, meta: string, extraMeta: string[] = [], badge?: string): StatusLineFields {
  return {
    icon: STATUS_ICON_TAG[status],
    title: meta,
    meta: extraMeta.length > 0 ? extraMeta : undefined,
    badge,
  };
}

export function formatToolHeaderQueued(requestId: string, totalCalls: number): string {
  return formatStatusLine(toolHeaderFields(requestId, `queued (${totalCalls} call(s))`));
}

export function formatToolHeaderRunning(requestId: string, done: number, total: number, failed: number): string {
  return formatStatusLine(toolHeaderFields(requestId, `running (${done}/${total} done, failed=${failed})`));
}

export function formatToolHeaderDone(requestId: string, resultCount: number): string {
  return formatStatusLine(toolHeaderFields(requestId, `done (${resultCount} result(s))`));
}

export function formatToolRow(
  status: ToolRowStatus,
  meta: string,
  exitCode?: number,
  truncated = false,
  extraBadge?: string,
): string {
  const extraMeta = typeof exitCode === "number" ? [`exit=${exitCode}`] : [];
  const badges = [truncated ? "[truncated]" : "", extraBadge ?? ""].filter((x) => x.trim().length > 0);
  const badge = badges.length > 0 ? badges.join(" ") : undefined;
  return `  ${formatStatusLine(toolRowFields(status, meta, extraMeta, badge), status)}`;
}

function formatPlannedToolRow(status: PlannedToolStatus, meta: string): string {
  const label = status === "error" ? "failed" : status;
  const raw = `  [${label}] ${meta}`;
  return colorizeStatusTags(raw);
}

function stepFromRequestId(requestId: string): number | null {
  const m = requestId.match(/(\d+)$/);
  if (!m) return null;
  const n = Number(m[1]);
  return Number.isFinite(n) ? n : null;
}

function colorizeStatusTags(text: string): string {
  return text
    .replaceAll("[done]", chalk.green("[done]"))
    .replaceAll("[failed]", chalk.red("[failed]"));
}

export function describeToolCallMeta(call: DelegatedCall): string {
  const id = call.id ?? "unknown";
  const tool = call.tool ?? "unknown";
  if (tool === "ReadFile") {
    const start = call.start ?? 1;
    const end = call.end ?? 200;
    return `${id} ${tool} ${call.path ?? ""} lines ${start}-${end}`.trim();
  }
  if (tool === "Search") {
    return `${id} ${tool} pattern="${call.pattern ?? ""}" dir=${call.dir ?? "."}`.trim();
  }
  if (tool === "WriteFile") {
    return `${id} ${tool} ${call.path ?? ""}`.trim();
  }
  if (tool === "EditFile") {
    const edits = Array.isArray(call.edits) ? call.edits.length : 0;
    const flags = [call.dry_run ? "dry_run" : "", call.expected_sha256 ? "sha_guard" : ""]
      .filter((x) => x.length > 0)
      .join(",");
    const suffix = flags ? ` (${flags})` : "";
    return `${id} ${tool} ${call.path ?? ""} edits=${edits}${suffix}`.trim();
  }
  const exec = resolveDelegatedExec(call);
  if (exec) {
    const args = exec.args?.length ? " " + exec.args.join(" ") : "";
    return `${id} ${tool} ${exec.cmd}${args}`.trim();
  }
  return `${id} ${tool}`;
}

function formatRendererError(tool: string, err: unknown): string {
  const msg = err instanceof Error ? err.message : String(err);
  return `tool renderer fallback: ${tool} (${msg})`;
}

export function renderToolCallMetaWithFallback(
  call: DelegatedCall,
  onDebug?: (message: string) => void,
  registry: Record<string, ToolRenderer> = TOOL_RENDERERS,
): string {
  const tool = call.tool ?? "unknown";
  const renderer = registry[tool];
  if (!renderer) {
    onDebug?.(`tool renderer fallback: ${tool} (missing renderer)`);
    return GENERIC_TOOL_RENDERER.renderCall(call, { describeToolCall: describeToolCallMeta });
  }
  try {
    return renderer.renderCall(call, { describeToolCall: describeToolCallMeta });
  } catch (err) {
    onDebug?.(formatRendererError(tool, err));
    return GENERIC_TOOL_RENDERER.renderCall(call, { describeToolCall: describeToolCallMeta });
  }
}

function splitOutputLines(text: string): string[] {
  if (!text) return [];
  return text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
}

function hardTruncateLine(line: string, maxWidth: number): string {
  if (maxWidth <= 0) return "";
  if (line.length <= maxWidth) return line;
  if (maxWidth <= 3) return ".".repeat(maxWidth);
  return `${line.slice(0, maxWidth - 3)}...`;
}

function formatHighContrastErrorBox(
  rawText: string,
  indent = "",
  maxLines = 5,
  maxContentWidth = 110,
): string[] {
  const raw = splitOutputLines(rawText)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
  if (raw.length === 0) return [];

  const columns = process.stdout.columns || 80;
  const innerCapByTerm = Math.max(16, columns - STAMP_PREFIX_WIDTH - indent.length - 4);
  const innerWidth = Math.max(10, Math.min(maxContentWidth, innerCapByTerm));
  const chunkLine = (line: string): string[] => {
    if (line.length <= innerWidth) return [line];
    const out: string[] = [];
    let i = 0;
    while (i < line.length) {
      out.push(line.slice(i, i + innerWidth));
      i += innerWidth;
    }
    return out;
  };

  const body: string[] = [];
  const maxBodyLines = Math.max(1, maxLines);
  for (const line of raw) {
    for (const part of chunkLine(line)) {
      if (body.length >= maxBodyLines) break;
      body.push(part);
    }
    if (body.length >= maxBodyLines) break;
  }
  const omitted = Math.max(0, raw.length - maxBodyLines);
  if (omitted > 0 && body.length > 0) {
    body[body.length - 1] = hardTruncateLine(`${body[body.length - 1]}  ... (${omitted} more lines)`, innerWidth);
  }

  const width = body.reduce((m, line) => Math.max(m, line.length), 0);
  const top = `${indent}+${"-".repeat(width + 2)}+`;
  const rows = body.map((line) => `${indent}| ${line.padEnd(width, " ")} |`);
  const bot = `${indent}+${"-".repeat(width + 2)}+`;
  const paint = (s: string): string => chalk.bgRgb(120, 0, 0).white(s);
  return [paint(top), ...rows.map((r) => paint(r)), paint(bot)];
}

function isEditToolFamily(toolName: string | undefined): boolean {
  if (!toolName) return false;
  return toolName === "WriteFile" || toolName === "EditFile" || toolName === "ApplyPatch";
}

type DiffStats = {
  fileCount: number;
  hunkCount: number;
  additions: number;
  deletions: number;
  lines: string[];
};

function parseUnifiedDiff(text: string): DiffStats | null {
  const lines = splitOutputLines(text);
  if (lines.length === 0) return null;
  const hasHunk = lines.some((line) => line.startsWith("@@"));
  const hasFileHeaders = lines.some((line) => isDiffFileHeaderLine(line, "--- ")) && lines.some((line) => isDiffFileHeaderLine(line, "+++ "));
  if (!hasHunk || !hasFileHeaders) return null;
  let fileCount = 0;
  let hunkCount = 0;
  let additions = 0;
  let deletions = 0;
  for (const line of lines) {
    if (isDiffFileHeaderLine(line, "+++ ")) fileCount += 1;
    else if (line.startsWith("@@")) hunkCount += 1;
    else if (line.startsWith("+") && !line.startsWith("+++ ")) additions += 1;
    else if (line.startsWith("-") && !line.startsWith("--- ")) deletions += 1;
  }
  return { fileCount, hunkCount, additions, deletions, lines };
}

function formatCollapsedDiffSummary(stats: DiffStats): string {
  return `  [diff] files=${stats.fileCount} hunks=${stats.hunkCount} +${stats.additions} -${stats.deletions} (Ctrl+O to expand)`;
}

function formatExpandedDiffLines(stats: DiffStats, maxWidth: number): string[] {
  const previewRaw = stats.lines.slice(0, TOOL_DIFF_PREVIEW_LINES).map((line) => hardTruncateLine(line, Math.max(10, maxWidth - 2)));
  // Reuse the existing LLM markdown diff highlighter so tool-row and markdown
  // diff visuals stay consistent.
  const colored = highlightCodeLines(previewRaw.join("\n"), "diff").map((line) => `  ${line}`);
  const hidden = Math.max(0, stats.lines.length - previewRaw.length);
  if (hidden > 0) {
    colored.push(chalk.dim(`  ... ${hidden} more diff lines (Ctrl+O to collapse)`));
  }
  return colored;
}

export function formatToolDetailLines(
  details: ToolRowDetails,
  expanded: boolean,
  maxLineWidth: number,
  options: ToolDetailRenderOptions = {},
): string[] {
  const stdoutLines = splitOutputLines(details.stdout);
  const stderrLines = splitOutputLines(details.stderr);
  const hasOutput = stdoutLines.length > 0 || stderrLines.length > 0;
  if (!hasOutput) return [];

  const maxWidth = Math.max(8, maxLineWidth);
  const diffStats = isEditToolFamily(options.toolName) ? parseUnifiedDiff(details.stdout) : null;
  if (!expanded) {
    if (diffStats) return [chalk.dim(formatCollapsedDiffSummary(diffStats))];
    return ["  ... output hidden (Ctrl+O to expand)"];
  }

  if (diffStats) {
    const rendered = formatExpandedDiffLines(diffStats, maxWidth);
    const errPreview = stderrLines.slice(0, TOOL_STDERR_PREVIEW_LINES);
    const hiddenErr = Math.max(0, stderrLines.length - errPreview.length);
    for (const line of errPreview) {
      rendered.push(chalk.red.dim(`  [stderr] ${hardTruncateLine(line, maxWidth - 11)}`));
    }
    if (hiddenErr > 0) {
      rendered.push(chalk.dim(`  ... ${hiddenErr} more stderr lines (Ctrl+O to collapse)`));
    }
    return rendered;
  }

  const outPreview = stdoutLines.slice(0, TOOL_STDOUT_PREVIEW_LINES);
  const errPreview = stderrLines.slice(0, TOOL_STDERR_PREVIEW_LINES);
  const hiddenCount = Math.max(0, stdoutLines.length - outPreview.length) + Math.max(0, stderrLines.length - errPreview.length);

  const rendered: string[] = [];
  for (const line of outPreview) {
    rendered.push(chalk.dim(`  ${hardTruncateLine(line, maxWidth - 2)}`));
  }
  for (const line of errPreview) {
    rendered.push(chalk.red.dim(`  [stderr] ${hardTruncateLine(line, maxWidth - 11)}`));
  }
  if (hiddenCount > 0) {
    rendered.push(chalk.dim(`  ... ${hiddenCount} more lines (Ctrl+O to collapse)`));
  }
  return rendered;
}

export function shouldCoalesceToolRowRender(
  lastRenderMs: number | undefined,
  nowMs: number,
  status: ToolRowRenderStatus,
  intervalMs = TOOL_RENDER_COALESCE_MS,
): boolean {
  if (status === "done" || status === "failed") return false;
  if (lastRenderMs === undefined) return false;
  return nowMs - lastRenderMs < intervalMs;
}

export function shouldGroupReadFileCalls(calls: DelegatedCall[]): boolean {
  let count = 0;
  for (const call of calls) {
    if (call.tool === "ReadFile") count += 1;
    if (count >= 2) return true;
  }
  return false;
}

function readFileTargetMeta(call: DelegatedCall): string {
  const start = call.start ?? 1;
  const end = call.end ?? 200;
  return `${call.path ?? "unknown"} lines ${start}-${end}`.trim();
}

export function formatGroupedReadFileChildRow(
  status: ToolRowStatus,
  target: string,
  exitCode?: number,
  truncated = false,
  extraBadge?: string,
): string {
  const extraMeta = typeof exitCode === "number" ? ` exit=${exitCode}` : "";
  const badgeParts = [truncated ? "[truncated]" : "", extraBadge ?? ""].filter((x) => x.trim().length > 0);
  const badge = badgeParts.length > 0 ? ` ${badgeParts.join(" ")}` : "";
  return `    [${status}] ${target}${extraMeta}${badge}`;
}

export function formatReadFileGroupHeader(total: number, done: number, failed: number): string {
  const base = `  [group] ReadFile (${total})`;
  if (done + failed <= 0) return base;
  if (done + failed < total) return `${base} running (${done}/${total} done, failed=${failed})`;
  if (failed > 0) return `${base} failed (${done}/${total} done, failed=${failed})`;
  return `${base} done`;
}

export function computeMissingDoneResultIds(expectedIds: string[], seenIds: Set<string>): string[] {
  const missing: string[] = [];
  for (const id of expectedIds) {
    if (!seenIds.has(id)) missing.push(id);
  }
  return missing;
}

interface WaitStateSnapshot {
  state: RunState;
  sinceMs: number;
}

interface ThinkBlock {
  step: number;
  content: string;
  charCount: number;
  headerRow: Text;
  bodyRow: Text;
  expanded: boolean;
}

function isWaitingState(state: RunState): boolean {
  return state === "thinking" || state === "tools_wait" || state === "tools_run";
}

export function shouldLockPlainInput(
  awaitingTask: boolean,
  taskDone: boolean,
  value: string,
): boolean {
  return !awaitingTask && !taskDone && value.length > 0 && !value.startsWith("/");
}

function initialExtensionsFromEnv(): string {
  const raw = (process.env.CORE_EXT_ORDER ?? "").trim();
  if (raw === "") return "";
  const names = raw
    .split(",")
    .map((x) => x.trim())
    .filter((x) => x.length > 0);
  if (names.length === 0) return "";
  return names.join(", ");
}

export function shouldRenderThinkingAfterStream(streamedSteps: Set<number>, step: number): boolean {
  return !streamedSteps.has(step);
}

interface TaggedSplit {
  think: string;
  answer: string;
}

function extractTaggedThinkAnswer(text: string): TaggedSplit | null {
  const raw = text ?? "";
  const lower = raw.toLowerCase();
  const tags: Array<{ open: string; close: string }> = [
    { open: "<thinking>", close: "</thinking>" },
    { open: "<think>", close: "</think>" },
  ];
  let best: { openIdx: number; bodyStart: number; closeIdx: number; closeLength: number } | null = null;
  for (const tag of tags) {
    let searchFrom = 0;
    while (searchFrom < lower.length) {
      const openIdx = lower.indexOf(tag.open, searchFrom);
      if (openIdx < 0) break;
      const bodyStart = openIdx + tag.open.length;
      const closeIdx = lower.indexOf(tag.close, bodyStart);
      if (closeIdx < 0) break;
      if (!best || openIdx > best.openIdx) {
        best = { openIdx, bodyStart, closeIdx, closeLength: tag.close.length };
      }
      searchFrom = bodyStart;
    }
  }
  if (!best) return null;
  const think = raw.slice(best.bodyStart, best.closeIdx).trim();
  const answer = raw.slice(best.closeIdx + best.closeLength).trim();
  return { think, answer };
}

function stripThinkTags(text: string): string {
  return text
    .replace(/<\/?\s*think(?:ing)?\s*>/gi, "")
    .replace(/(?:^|[\s`])<\/?(?:t|th|thi|thin|think|thinki|thinkin|thinking)>/gi, (m) => m.match(/^\s/) ? m[0]! : "")
    .replace(/^(?:hinking|inking|nking|king|ing|ng|g)>/i, "");
}

// Strip BOTH the tags AND the body content of <thinking>...</thinking>
// blocks. Used for live streaming render so the user sees just the answer
// (or a placeholder) instead of the model's reasoning leaking through
// before the closing tag arrives.
//
// Handles three states:
//   - Closed block: <thinking>foo</thinking>bar → "[thinking]\nbar"
//   - Open block (mid-stream): <thinking>foo → "[thinking…]"
//   - No block: foo → "foo" (after standard tag-strip)
//
// Returns the visible portion only; the full thinking content is still
// preserved in the underlying buffer for the final render path
// (extractTaggedThinkAnswer at thinking_stream_end).
function stripThinkBlocksForLive(text: string): string {
  if (!text) return "";
  // Strip closed <thinking>...</thinking> blocks (case-insensitive,
  // tolerant of <think>/<thinking>). Replace with a single placeholder
  // so the user knows reasoning is happening but not what it says.
  let out = text.replace(/<think(?:ing)?\s*>[\s\S]*?<\/think(?:ing)?\s*>/gi, "[thinking]\n");
  // Strip an unclosed trailing <thinking>... — anything from the open
  // tag to end-of-buffer. This is the in-flight case where the model
  // hasn't emitted </thinking> yet. Show a thinking placeholder.
  const openMatch = out.match(/<think(?:ing)?\s*>[\s\S]*$/i);
  if (openMatch) {
    out = out.slice(0, openMatch.index!) + "[thinking…]";
  }
  // Final pass: strip any orphan tag fragments left behind by
  // partial-token mid-stream parsing.
  return stripThinkTags(out);
}

export function applyToolProgressCounters(
  counters: ToolBatchCounters,
  results: DelegatedResult[],
): ToolBatchCounters {
  const nextSeen = new Set(counters.seen);
  let done = counters.done;
  let failed = counters.failed;
  for (const result of results) {
    if (nextSeen.has(result.tool_call_id)) continue;
    nextSeen.add(result.tool_call_id);
    if (result.exit_code === 0) done += 1;
    else failed += 1;
  }
  return {
    total: counters.total,
    done,
    failed,
    running: Math.max(0, counters.total - done - failed),
    seen: nextSeen,
  };
}

export function formatCount(n: number): string {
  if (n < 1_000) return `${n}`;
  if (n < 1_000_000) {
    const k = (n / 1_000).toFixed(1);
    if (n >= 100_000) return `${k.replace(/\.0$/, "")}k`;
    return `${k}k`;
  }
  return `${(n / 1_000_000).toFixed(1)}M`;
}

export function formatContextUsage(tokensEst: number, limit: number): string {
  if (limit <= 0) return `ctx: ${formatCount(tokensEst)}`;
  const pct = Math.round((tokensEst * 100) / limit);
  return `ctx: ${formatCount(tokensEst)}/${formatCount(limit)} (${pct}%)`;
}

export function colorizeContextUsageSegment(
  segment: string,
  tokensEst: number,
  limit: number,
  baseColor: (s: string) => string,
): string {
  if (limit > 0) {
    const ratio = tokensEst / limit;
    if (ratio >= 0.9) return chalk.red(segment);
    if (ratio >= 0.75) return chalk.yellow(segment);
  }
  return baseColor(segment);
}

// ---------------------------------------------------------------------------
// AgentUI
// ---------------------------------------------------------------------------

export class AgentUI {
  private tui:       TUI;
  private history:   Box;
  private statusBar: Text;
  private cmdInput:  Editor;
  private step  = 0;
  private model = "";
  private branch = "";
  private loadedExtensions = "";
  private latestContextUsage?: { tokensEst: number; limit: number };
  private overlayHandle: OverlayHandle | null = null;
  private readonly toolRows = new Map<string, Text>();
  private readonly toolDetailRows = new Map<string, Text>();
  private readonly toolRowMeta = new Map<string, string>();
  private readonly toolRowToolNames = new Map<string, string>();
  private readonly toolRowKinds = new Map<string, ToolRowKind>();
  private readonly toolRowDetails = new Map<string, ToolRowDetails>();
  private readonly lastToolRenderMs = new Map<string, number>();
  private readonly pendingToolRenderTimers = new Map<string, NodeJS.Timeout>();
  private readonly toolBatchHeaders = new Map<string, Text>();
  private readonly toolGroups = new Map<string, ToolGroupState>();
  private readonly toolBatchState = new Map<string, ToolBatchState>();
  private readonly runStateHintsShown = new Set<HintPhase>();
  private readonly thinkBlocks = new Map<number, ThinkBlock>();
  private readonly streamRows = new Map<string, Text>();
  private readonly streamBuffers = new Map<string, {
    step: number;
    text: string;
    lastSeq: number;
    truncatedForParse: boolean;
    lastRenderAtMs: number;
  }>();
  // M-AI-STEP-STREAMING-THINKING v0.18.8: per-stream_id accumulator for
  // API-level reasoning (ThinkingDelta from claude-opus-4.5+ extended-
  // thinking, OpenAI o1/o3, Gemini 2.5+ thoughts). Kept separate from
  // streamBuffers so reasoning never mixes with content. Flushed into a
  // [reason] side panel via addReasoningBlock at thinking_stream_end.
  private readonly reasoningBuffers = new Map<string, string>();
  private readonly pendingStreamRenderTimers = new Map<string, NodeJS.Timeout>();
  private readonly streamedSteps = new Set<number>();
  private readonly streamRenderedSteps = new Set<number>();
  private readonly plannedToolHeaders = new Map<number, Text>();
  private readonly plannedToolOrderByStep = new Map<number, string[]>();
  private readonly plannedToolEntries = new Map<string, PlannedToolEntry>();
  private readonly runtimeToPlannedKey = new Map<string, string>();
  private readonly requestsUsingPlannedTimeline = new Set<string>();
  private readonly composeCards = new Map<string, ComposeCardState>();
  private readonly composeOrder: string[] = [];
  private selectedComposeIdx = -1;
  private composeFooterStatus = "";
  private readonly thinkStepOrder: number[] = [];  // insertion order; used for ctrl+t cycling
  private selectedThinkIdx = -1;                   // index into thinkStepOrder, -1 = none selected
  /** True once the first task is complete; enables free-text follow-ups. */
  private taskDone = false;
  /** Package version shown as a startup banner in the history pane. */
  private ailangVersion: string;
  private version: string;

  /** Called when the user selects a new model. */
  onModelChange?: (model: string) => void;

  /** Called when the user triggers /abort or Ctrl+C. */
  onAbort?: () => void;

  /** Called when the user presses ESC to interrupt a running task. */
  onInterrupt?: () => void;

  /**
   * Called when the user submits a plain-text follow-up after task completion.
   * index.ts wires this to RuntimeProcess.sendUserMessage().
   */
  onUserMessage?: (content: string) => void;

  /**
   * Called when the user types the initial task (only when awaitingTask is true).
   */
  onInitialTask?: (task: string) => void;

  /** The AILANG runtime process, or undefined once it has exited. */
  runtimeProcess: RuntimeProcess | undefined;

  /** True when waiting for the user to type the initial task via cmdInput. */
  private awaitingTask = false;
  private waitState: WaitStateSnapshot = { state: "idle", sinceMs: Date.now() };
  private spinnerFrame = 0;
  private lastUpdateMs = Date.now();
  private statusTick: NodeJS.Timeout;
  private activityLogEnabled = process.env.TUI_ACTIVITY_LOG === "1";
  private activityPane: Box | null = null;
  private activeToolRequestId: string | null = null;
  private toolOutputExpanded = true;
  private lastToolPreviewWidth = 0;
  private unknownRequestCounter = 0;
  private unknownToolRowCounter = 0;
  private missingDelegatedRequestId: string | null = null;
  private missingNativeRequestId: string | null = null;
  private readonly composeVerbose = (() => {
    const v = (process.env.AILANG_SUBAGENT_VERBOSE ?? "").trim().toLowerCase();
    return v === "1" || v === "true" || v === "yes";
  })();
  private readonly composeAutoCollapse = (() => {
    const v = (process.env.AILANG_SUBAGENT_AUTO_COLLAPSE ?? "").trim().toLowerCase();
    return v === "1" || v === "true" || v === "yes";
  })();
  private readonly showToolJsonStream = (() => {
    const v = (process.env.MOTOKO_SHOW_TOOL_JSON_STREAM ?? "").trim().toLowerCase();
    return v === "1" || v === "true" || v === "yes";
  })();
  private readonly finalOnly = (() => {
    const v = (process.env.MOTOKO_FINAL_ONLY ?? process.env.MOTOKO_HEURISTIC_FINAL_ONLY ?? "").trim().toLowerCase();
    return v === "1" || v === "true" || v === "yes";
  })();

  constructor({ version, model, ailangVersion, extensions }: { version?: string; model?: string; ailangVersion?: string; extensions?: string[] } = {}) {
    this.version = version ?? "0.0.0";
    this.ailangVersion = ailangVersion ?? "unknown";
    this.model = model ?? "";
    this.loadedExtensions = extensions && extensions.length > 0
      ? extensions.join(", ")
      : initialExtensionsFromEnv();
    try { this.branch = execSync("git rev-parse --abbrev-ref HEAD").toString().trim(); } catch {}
    const terminal = new ProcessTerminal();

    this.tui = new TUI(terminal);


    // History pane: a plain Box; children accumulate downward.
    this.history = new Box();

    // Version line under startup banner space (banner is printed via
    // stdout in main() — not here, because raw ANSI inside Text children
    // corrupts on re-render).
    // Remaining components

    // Status bar: dim styling via bgFn.
    this.statusBar = styledText("", chalk.dim);

    // Command input: Editor component (replaces Input) for slash-command
    // tab-complete.  Requires TUI reference for focus management.
    this.cmdInput = new Editor(this.tui, EDITOR_THEME, {
      autocompleteMaxVisible: 10,
    });
    this.cmdInput.onSubmit = (value: string) => {
      this.cmdInput.setText("");
      this.handleCommand(value.trim());
    };
    // Wire autocomplete — shows /model, /abort when user types "/"
    this.cmdInput.setAutocompleteProvider(createCommandAutocompleteProvider());

    // Layout: history → optional activity pane → status bar → editor input.
    this.tui.addChild(this.history);
    if (this.activityLogEnabled) {
      this.activityPane = new Box();
      this.activityPane.addChild(styledText("[activity] enabled", chalk.dim));
      this.tui.addChild(this.activityPane);
    }
    this.tui.addChild(this.statusBar);
    this.tui.addChild(this.cmdInput);

    this.tui.setFocus(this.cmdInput);

    // Ctrl+C: intercept \x03 via TUI input listener (raw mode suppresses SIGINT).
    // The listener runs before the focused component, so it takes priority over
    // the Editor's built-in copy-selection handling.
    this.tui.addInputListener((data) => {
      if (matchesKey(data, "ctrl+c")) {
        this.onAbort?.();
        return { consume: true };
      }
      // ESC while a task is running: kill the runtime process immediately.
      // Do NOT consume ESC when idle — let Editor handle it (e.g. cancel autocomplete).
      if (matchesKey(data, "escape") && this.runtimeProcess && !this.taskDone) {
        this.appendHistoryStyled("Task interrupted", chalk.yellow);
        this.tui.requestRender();
        this.onInterrupt?.();
        return { consume: true };
      }
      // ctrl+t: cycle backward through think blocks (most recent → oldest → wrap).
      // Does not interfere with the follow-up editor.
      if (matchesKey(data, "ctrl+t") && this.thinkStepOrder.length > 0) {
        const nextIdx = this.selectedThinkIdx === -1
          ? this.thinkStepOrder.length - 1
          : (this.selectedThinkIdx - 1 + this.thinkStepOrder.length) % this.thinkStepOrder.length;
        this.selectThinkBlock(nextIdx);
        this.tui.requestRender();
        return { consume: true };
      }
      if (matchesKey(data, "ctrl+o")) {
        if (this.composeOrder.length > 0) {
          const idx = this.selectedComposeIdx === -1 ? this.composeOrder.length - 1 : this.selectedComposeIdx;
          const composeId = this.composeOrder[idx];
          if (composeId) {
            const card = this.composeCards.get(composeId);
            if (card) {
              card.expanded = !card.expanded;
              this.renderComposeCard(card);
              this.selectedComposeIdx = idx;
              this.tui.requestRender();
              return { consume: true };
            }
          }
        }
        this.toolOutputExpanded = !this.toolOutputExpanded;
        this.refreshAllToolDetailRows();
        this.tui.requestRender();
        return { consume: true };
      }
      return undefined;
    });
    // Also handle SIGINT for cases where the terminal still delivers it
    // (e.g. external kill -INT or non-raw contexts).
    process.on("SIGINT", () => this.onAbort?.());

    // Populate the status bar before start() so the first render includes it.
    this.updateStatus();
    this.statusTick = setInterval(() => {
      if (isWaitingState(this.waitState.state)) {
        this.spinnerFrame = (this.spinnerFrame + 1) % 4;
        this.maybeEmitSlowHint();
        this.updateStatus();
        this.tui.requestRender();
        return;
      }
      this.updateStatus();
    }, 150);
    this.tui.start();
    // Explicit render so children added before start() (e.g. version banner)
    // are visible immediately.
    this.tui.requestRender();
  }

  // ---------------------------------------------------------------------------
  // Event handler
  // ---------------------------------------------------------------------------

  private addActivity(message: string): void {
    if (!this.activityPane) return;
    const ts = new Date().toISOString().slice(11, 19);
    this.activityPane.addChild(styledText(`[${ts}] ${message}`, chalk.dim));
  }

  private stamp(message: string): string {
    return `[${formatTimestamp()}] ${message}`;
  }

  private appendHistoryPlain(message: string): void {
    this.history.addChild(plainText(this.stamp(message)));
  }

  private appendHistoryStyled(message: string, style: (s: string) => string): void {
    this.history.addChild(styledText(this.stamp(message), style));
  }

  private appendHistoryMarkdown(message: string): void {
    this.history.addChild(new Markdown(this.stamp(message), 0, 0, MINIMAL_THEME));
  }

  private setRunState(next: RunState): void {
    if (this.waitState.state === next) return;
    const prev = this.waitState.state;
    this.waitState = { state: next, sinceMs: Date.now() };
    this.spinnerFrame = 0;
    if (next === "thinking" && prev !== "thinking") this.runStateHintsShown.delete("thinking");
    const prevWasTools = prev === "tools_wait" || prev === "tools_run";
    const nextIsTools = next === "tools_wait" || next === "tools_run";
    if (nextIsTools && !prevWasTools) this.runStateHintsShown.delete("tools");
    this.addActivity(`state -> ${next}`);
  }

  private maybeEmitSlowHint(): void {
    const elapsedMs = Date.now() - this.waitState.sinceMs;
    if (this.waitState.state === "thinking" && elapsedMs >= 10_000 && !this.runStateHintsShown.has("thinking")) {
      this.runStateHintsShown.add("thinking");
      this.appendHistoryStyled("Still waiting on model...", chalk.dim);
      this.lastUpdateMs = Date.now();
      return;
    }
    if ((this.waitState.state === "tools_wait" || this.waitState.state === "tools_run") && elapsedMs >= 20_000 && !this.runStateHintsShown.has("tools")) {
      this.runStateHintsShown.add("tools");
      this.appendHistoryStyled("Tool batch taking longer than usual...", chalk.dim);
      this.lastUpdateMs = Date.now();
    }
  }

  handleEvent(event: AgentEvent): void {
    this.lastUpdateMs = Date.now();
    switch (event.type) {
      case "session_start":
        this.composeFooterStatus = "";
        this.toolOutputExpanded = true;
        this.refreshAllToolDetailRows();
        if (!this.taskDone && !this.awaitingTask) {
          if (this.waitState.state !== "thinking") {
            this.appendHistoryStyled("Runtime is reasoning...", chalk.dim);
          }
          this.setRunState("thinking");
        } else {
          this.setRunState("idle");
        }
        this.model = event.model;
        // Conversational re-emits of session_start (one per user turn in
        // agent_loop_v2.conversation_loop_v2) omit the version fields,
        // which would render as "AILANG built undefined | Core Runtime
        // vundefined". Only render the banner when the full version
        // payload is present (i.e. the runtime-startup session_start from
        // rpc.ail). Conversational turns get a quieter status update.
        if (event.ailangBuilt && event.brainVersion) {
          this.appendHistoryStyled(`AILANG built ${event.ailangBuilt} | Core Runtime v${event.brainVersion} | TUI v${this.version}`, chalk.dim);
        }
        if (Array.isArray(event.loaded_extensions)) {
          const names = event.loaded_extensions;
          const extText = names.length === 0 ? "(none)" : names.join(", ");
          this.loadedExtensions = extText;
          this.appendHistoryStyled(`Loaded extensions: ${extText}`, chalk.dim);
        }
        break;

      case "thinking":
        if (this.waitState.state === "tools_wait" || this.waitState.state === "tools_run") {
          this.appendHistoryStyled("Tool results received. Continuing reasoning...", chalk.dim);
        } else if (this.waitState.state !== "thinking") {
          this.appendHistoryStyled("Runtime is reasoning...", chalk.dim);
        }
        this.setRunState("thinking");
        this.step = event.step;
        {
          if (event.think !== undefined || event.answer !== undefined) {
            // Runtime pre-split the think/answer portions.
            // Think block: render as collapsed summary + hidden body.
            const thinkContent = this.stripToolJsonBlocks(event.think ?? "").trim();
            if (thinkContent && shouldRenderThinkingAfterStream(this.streamedSteps, event.step)) {
              this.addThinkBlock(event.step, thinkContent);
            }
            // Answer portion: render as markdown.
            const answerRaw = event.answer ?? "";
            if (answerRaw.trim() && shouldRenderThinkingAfterStream(this.streamedSteps, event.step)) {
              const answer = this.stripToolJsonBlocks(answerRaw);
              if (answer.trim()) {
                this.appendHistoryMarkdown(answer);
              }
            }
          } else {
            // Fallback: no pre-split fields (older runtime)
            const visible = this.stripToolJsonBlocks(event.text);
            if (visible.trim() && shouldRenderThinkingAfterStream(this.streamedSteps, event.step)) {
              this.appendHistoryMarkdown(visible);
            }
          }
        }
        break;
      case "context_usage":
        this.latestContextUsage = { tokensEst: event.tokens_est, limit: event.limit };
        this.step = event.step;
        break;
      case "thinking_stream_start":
        if (isInternalComposeStream(event.stream_id)) break;
        if (this.waitState.state !== "thinking") {
          this.appendHistoryStyled("Runtime is reasoning...", chalk.dim);
        }
        this.setRunState("thinking");
        this.step = event.step;
        this.streamedSteps.add(event.step);
        {
          if (!this.finalOnly) {
            const row = styledText(this.stamp(""), chalk.reset);
            this.history.addChild(row);
            this.streamRows.set(event.stream_id, row);
          }
          this.streamBuffers.set(event.stream_id, {
            step: event.step,
            text: "",
            lastSeq: -1,
            truncatedForParse: false,
            lastRenderAtMs: 0,
          });
        }
        break;
      case "thinking_delta":
        {
          if (isInternalComposeStream(event.stream_id)) {
            if (this.applyInternalComposeDelta(event.stream_id, event.text_delta)) break;
          }
          const current = this.streamBuffers.get(event.stream_id);
          if (!current) break;
          // seq=0 is a placeholder used by the AILANG-side per-chunk
          // callback (M-AI-STEP-STREAMING v0.18.7) — every event from
          // upstream stepWithStream carries seq=0 because AILANG
          // closures can't easily maintain monotonic counters. Treat
          // seq=0 as "always accept" and rely on arrival order;
          // strict-ordering dedup remains for legacy emitters that
          // populate seq with real values.
          if (event.seq !== 0 && event.seq <= current.lastSeq) break;
          if (event.seq > current.lastSeq) current.lastSeq = event.seq;
          current.text += event.text_delta;
          if (current.text.length > STREAM_TEXT_MAX_BYTES) {
            current.text = current.text.slice(-STREAM_TEXT_MAX_BYTES);
            current.truncatedForParse = true;
          }
          this.syncPlannedToolsFromStream(current.step, current.text);
          this.scheduleStreamRender(event.stream_id);
          this.step = event.step;
        }
        break;
      case "reasoning_delta":
        // API-level reasoning chunk (v0.18.8 ThinkingDelta from
        // claude-opus-4.5+ extended-thinking, OpenAI o1/o3, Gemini
        // 2.5+ thoughts). NOT mixed into the per-stream_id content
        // buffer — accumulated separately into reasoningBuffers and
        // rendered into a side panel via addReasoningBlock at
        // thinking_stream_end. We also append a dim placeholder live
        // so the user knows reasoning is happening.
        {
          if (isInternalComposeStream(event.stream_id)) break;
          const prev = this.reasoningBuffers.get(event.stream_id) ?? "";
          this.reasoningBuffers.set(event.stream_id, prev + event.text_delta);
          this.step = event.step;
        }
        break;
      case "thinking_stream_error":
        if (isInternalComposeStream(event.stream_id)) break;
        this.appendHistoryStyled(`Stream error: ${event.message}`, chalk.red.dim);
        break;
      case "thinking_stream_end":
        if (isInternalComposeStream(event.stream_id)) break;
        this.clearPendingStreamRender(event.stream_id);
        if (event.status === "errored") {
          this.setRunState("error");
        }
        {
          const buf = this.streamBuffers.get(event.stream_id);
          const finalVisible = this.stripToolJsonBlocks(buf?.text ?? "").trim();
          const tagged = extractTaggedThinkAnswer(finalVisible);
          const hasPlannedTools = (this.plannedToolOrderByStep.get(event.step)?.length ?? 0) > 0;
          const preferred = hasPlannedTools ? "" : (tagged?.answer ?? finalVisible);
          const finalForRender = this.finalOnly ? (tagged?.answer ?? "") : preferred;
          if (hasPlannedTools) {
            const thinkForBlock = tagged?.think ?? finalVisible;
            if (thinkForBlock) this.addThinkBlock(event.step, thinkForBlock);
          } else if (tagged?.think) {
            this.addThinkBlock(event.step, tagged.think);
          }
          if (event.status === "completed") {
            if (!this.finalOnly && finalForRender.length > 0) {
              this.appendHistoryMarkdown(finalForRender);
              this.streamRenderedSteps.add(event.step);
            }
          } else {
            if (!this.finalOnly && finalForRender.length > 0) {
              this.appendHistoryMarkdown(finalForRender);
              this.streamRenderedSteps.add(event.step);
            }
            this.appendHistoryStyled(
              event.status === "aborted" ? "Stream aborted" : "Stream ended with error",
              chalk.dim,
            );
          }
        }
        const row = this.streamRows.get(event.stream_id);
        if (row) this.history.removeChild(row);
        this.clearPendingStreamRender(event.stream_id);
        // Flush API-level reasoning into a side panel (v0.18.8). Native
        // reasoning from claude-opus-4.5+/o1/o3/gemini-2.5+ accumulates in
        // reasoningBuffers separately from content; render here as a
        // [reason] block alongside any [think] block from <thinking>
        // tag-convention content.
        const reasoningText = this.reasoningBuffers.get(event.stream_id);
        if (reasoningText) {
          this.addReasoningBlock(event.step, reasoningText);
        }
        this.reasoningBuffers.delete(event.stream_id);
        this.streamBuffers.delete(event.stream_id);
        this.streamRows.delete(event.stream_id);
        this.tui.requestRender(true);
        break;

      case "proposed_cmd":
        this.appendHistoryStyled(`$ ${event.cmd}`, chalk.cyanBright.bold);
        break;

      case "proposed_ailang": {
        this.appendHistoryStyled("AILANG snippet:", chalk.cyanBright.bold);
        const lines = highlightCodeLines(event.code, "ailang");
        for (const line of lines) {
          this.appendHistoryPlain(`  ${line}`);
        }
        break;
      }

      case "ailang_check":
        if (event.passed) {
          this.appendHistoryStyled("  type-check passed", chalk.greenBright);
        } else {
          this.appendHistoryStyled(
            `  type-check failed (${event.attempt}/${event.max_attempts})`,
            chalk.redBright,
          );
          const errBox = formatHighContrastErrorBox(event.errors, "  ", 5);
          if (errBox.length > 0) this.appendHistoryStyled(errBox.join("\n"), chalk.redBright.bold);
        }
        break;
      case "compose_start":
        {
          const card = this.createComposeCard(event);
          this.composeFooterStatus = `subagent · ${event.compose_id} · attempt 1/${event.max_attempts} · authoring…`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_author_delta":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const prior = this.ensureComposeAttempt(card, event.attempt);
          prior.authorDelta = prior.authorStreamSeen === true
            ? mergeSnapshotWithStream(prior.authorDelta, event.delta)
            : prior.authorDelta + event.delta;
          card.attempts.set(event.attempt, prior);
          this.composeFooterStatus = `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · authoring…`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_author_error":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const prior = this.ensureComposeAttempt(card, event.attempt);
          prior.authorError = `${event.mode ?? "unknown"}: ${event.error}`;
          card.attempts.set(event.attempt, prior);
          this.composeFooterStatus = `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · author stream error`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_author_tool_call":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const prior = this.ensureComposeAttempt(card, event.attempt);
          const line = `${event.tool ?? "tool"} args=${String(event.args ?? "").slice(0, 160)}`;
          prior.authorToolCalls = [...(prior.authorToolCalls ?? []), line];
          card.attempts.set(event.attempt, prior);
          this.composeFooterStatus = `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · author tool call…`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_author_tool_result":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const prior = this.ensureComposeAttempt(card, event.attempt);
          const status = event.ok ? "ok" : "error";
          const line = `${event.tool ?? "tool"} ${status} bytes=${event.bytes ?? 0}${event.truncated ? " truncated" : ""} ${String(event.excerpt ?? "").slice(0, 160)}`;
          prior.authorToolResults = [...(prior.authorToolResults ?? []), line];
          card.attempts.set(event.attempt, prior);
          this.composeFooterStatus = `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · author tool result`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_author_ledger_snapshot":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const prior = this.ensureComposeAttempt(card, event.attempt);
          prior.authorLedgerSnapshot = `entries=${event.entries ?? 0} budget=${event.budget_used ?? 0}/${event.budget_cap ?? 0}`;
          card.attempts.set(event.attempt, prior);
          this.composeFooterStatus = `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · author ledger ready`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_snippet": {
        const card = this.ensureComposeCard(event.compose_id);
        if (!card) break;
        const prior = this.ensureComposeAttempt(card, event.attempt);
        prior.snippet = event.code;
        card.attempts.set(event.attempt, prior);
        this.composeFooterStatus = `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · checking…`;
        this.renderComposeCard(card);
        break;
      }
      case "compose_check":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const prior = this.ensureComposeAttempt(card, event.attempt);
          prior.checkPassed = event.passed;
          prior.checkErrors = event.errors ?? "";
          card.attempts.set(event.attempt, prior);
          this.composeFooterStatus = event.passed
            ? `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · check passed · executing…`
            : `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · check failed`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_retry":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const prevAttempt = event.attempt - 1;
          const prev = this.ensureComposeAttempt(card, prevAttempt);
          prev.retryReason = event.reason;
          card.attempts.set(prevAttempt, prev);
          this.composeFooterStatus = `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · retrying…`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_exec":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const attempts = Array.from(card.attempts.keys());
          const latestAttempt = attempts.length > 0 ? Math.max(...attempts) : 1;
          const a = this.ensureComposeAttempt(card, latestAttempt);
          a.stdout = event.stdout;
          a.stderr = event.stderr;
          a.exitCode = event.exit_code;
          card.attempts.set(latestAttempt, a);
          this.composeFooterStatus = `subagent · ${event.compose_id} · summarizing…`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_claimcheck_informalize_delta":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const prior = this.ensureComposeAttempt(card, event.attempt);
          prior.claimcheckInformalizeDelta = mergeSnapshotWithStream(prior.claimcheckInformalizeDelta ?? "", event.delta);
          card.attempts.set(event.attempt, prior);
          this.composeFooterStatus = `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · claimcheck pass 1…`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_claimcheck_informalize_result":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const prior = this.ensureComposeAttempt(card, event.attempt);
          prior.claimcheckInformalization = event.informalization;
          card.attempts.set(event.attempt, prior);
          this.composeFooterStatus = `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · claimcheck pass 2…`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_claimcheck_compare_delta":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const prior = this.ensureComposeAttempt(card, event.attempt);
          prior.claimcheckCompareDelta = mergeSnapshotWithStream(prior.claimcheckCompareDelta ?? "", event.delta);
          card.attempts.set(event.attempt, prior);
          this.composeFooterStatus = `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · claimcheck pass 2…`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_claimcheck_compare_result":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          const prior = this.ensureComposeAttempt(card, event.attempt);
          prior.claimcheckVerdict = event.verdict;
          prior.claimcheckConfidence = event.confidence;
          prior.claimcheckReason = event.reason;
          if ((event.informalization ?? "").trim() !== "") {
            prior.claimcheckInformalization = event.informalization;
          }
          card.attempts.set(event.attempt, prior);
          this.composeFooterStatus = `subagent · ${event.compose_id} · attempt ${event.attempt}/${card.maxAttempts} · claimcheck ${event.verdict}`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_summary_delta":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          card.summaryDelta = mergeSnapshotWithStream(card.summaryDelta, event.delta);
          this.composeFooterStatus = `subagent · ${event.compose_id} · summarizing…`;
          this.renderComposeCard(card);
        }
        break;
      case "compose_result":
        {
          const card = this.ensureComposeCard(event.compose_id);
          if (!card) break;
          card.summary = event.summary;
          card.resultExitCode = event.exit_code;
          card.resultAttempts = event.attempts;
          card.resultTruncated = event.truncated;
          card.telemetryJson = event.telemetry_json ?? "";
          card.finishedAtMs = Date.now();
          if (this.composeAutoCollapse && !this.composeVerbose) card.expanded = false;
          this.composeFooterStatus = "";
          this.renderComposeCard(card);
        }
        break;

      case "obs":
        if (event.stdout) {
          if (event.exit_code === 0) this.appendHistoryPlain(event.stdout);
          else this.appendHistoryStyled(event.stdout, chalk.red.dim);
        }
        if (event.stderr) {
          this.appendHistoryStyled(`[stderr] ${event.stderr}`, chalk.red.dim);
        }
        break;

      case "done":
        if (event.output && event.output.trim()) {
          const visible = this.stripToolJsonBlocks(event.output).trim();
          const tagged = extractTaggedThinkAnswer(visible);
          if (this.finalOnly) {
            if (tagged?.think) this.addThinkBlock(event.step, tagged.think);
            const finalText = tagged?.answer ?? visible;
            if (finalText.trim()) this.appendHistoryMarkdown(finalText.trim());
          } else if (!this.streamRenderedSteps.has(event.step)) {
            if (tagged?.answer) this.appendHistoryMarkdown(tagged.answer);
            else if (visible) this.appendHistoryMarkdown(visible);
            else this.appendHistoryMarkdown(event.output.trim());
          }
        }
        this.composeFooterStatus = "";
        this.setRunState("idle");
        // Mark task done so plain-text input routes to the runtime process as follow-ups.
        this.taskDone = true;
        // Return keyboard focus to input once the task is complete.
        this.tui.setFocus(this.cmdInput);
        this.updateStatus();
        break;

      case "warning":
        this.appendHistoryStyled(`Warning: ${event.message}`, chalk.yellow);
        break;
      case "error":
        this.composeFooterStatus = "";
        this.setRunState("error");
        this.appendHistoryStyled(`Error: ${event.message}`, chalk.redBright);
        // Runtime is still alive after an error; mark task done so the next
        // plain-text input routes to sendUserMessage in the live process.
        this.taskDone = true;
        this.tui.setFocus(this.cmdInput);
        this.updateStatus();
        break;
      case "tool_calls":
        this.setRunState("tools_wait");
        this.appendHistoryStyled("Waiting for delegated tool results...", chalk.dim);
        this.renderToolCalls(this.resolveRequestIdForEvent("tool_calls", (event as { request_id?: string }).request_id), event.tool_calls);
        break;
      case "tool_results":
        this.applyToolResults(this.resolveRequestIdForEvent("tool_results", (event as { request_id?: string }).request_id), event.phase, event.results);
        break;
      case "native_tool_calls":
        this.renderToolCalls(this.resolveRequestIdForEvent("native_tool_calls", (event as { request_id?: string }).request_id), event.tool_calls, false);
        break;
      case "native_tool_results":
        this.applyNativeToolResults(this.resolveRequestIdForEvent("native_tool_results", (event as { request_id?: string }).request_id), event.results);
        break;
    }

    this.updateStatus();
    this.tui.requestRender();
  }

  private isToolCallEnvelope(v: unknown): v is { tool_calls: unknown[] } {
    if (!v || typeof v !== "object") return false;
    const obj = v as { tool_calls?: unknown };
    return Array.isArray(obj.tool_calls);
  }

  /**
   * Scan forward from pos in hay for the closing ``` that is NOT inside a
   * JSON double-quoted string.  Returns the index of the first backtick of
   * the closing fence, or -1 if not found.
   */
  private findJsonFenceClose(hay: string, pos: number): number {
    let inStr = false;
    let escaped = false;
    while (pos < hay.length) {
      const ch = hay[pos];
      if (escaped) {
        escaped = false;
      } else if (inStr) {
        if (ch === "\\") escaped = true;
        else if (ch === '"') inStr = false;
      } else {
        if (ch === "`" && hay[pos + 1] === "`" && hay[pos + 2] === "`") {
          return pos;
        }
        if (ch === '"') inStr = true;
      }
      pos++;
    }
    return -1;
  }

  /**
   * Yield every ```json … ``` block in text, using quote-aware closing-fence
   * detection so backticks inside JSON string values don't truncate the block.
   */
  private *jsonFenceBlocks(
    text: string,
  ): Generator<{ openStart: number; body: string; closeEnd: number }> {
    const openRe = /```(?:json|JSON|Json|jsonc|JSONC|Jsonc)?[ \t]*\n/g;
    let m: RegExpExecArray | null;
    while ((m = openRe.exec(text)) !== null) {
      const openStart = m.index;
      const bodyStart = openRe.lastIndex;
      const closeIdx = this.findJsonFenceClose(text, bodyStart);
      if (closeIdx === -1) break;
      yield { openStart, body: text.slice(bodyStart, closeIdx).trim(), closeEnd: closeIdx + 3 };
      openRe.lastIndex = closeIdx + 3;
    }
  }

  private isLikelyToolCallBody(body: string): boolean {
    const compact = body.trim();
    if (compact.length === 0) return false;
    try {
      const parsed = JSON.parse(compact) as unknown;
      return this.isToolCallEnvelope(parsed);
    } catch {
      // Streaming may produce almost-valid JSON blocks; use strict-ish heuristic.
      return compact.includes("\"tool_calls\"") && compact.includes("\"tool\"") && compact.includes("\"id\"");
    }
  }

  private collapseThinkBlock(block: ThinkBlock): void {
    block.expanded = false;
    block.bodyRow.setText("");
    block.headerRow.setText(this.renderThinkHeader(block.step, block.charCount, false));
  }

  private expandThinkBlock(block: ThinkBlock): void {
    block.expanded = true;
    block.bodyRow.setText(this.renderThinkContent(block.content));
    block.headerRow.setText(this.renderThinkHeader(block.step, block.charCount, true));
  }

  /** Collapse the previously selected block, expand the one at idx, update selection. */
  private selectThinkBlock(idx: number): void {
    if (this.selectedThinkIdx >= 0 && this.selectedThinkIdx < this.thinkStepOrder.length) {
      const prevBlock = this.thinkBlocks.get(this.thinkStepOrder[this.selectedThinkIdx]!);
      if (prevBlock?.expanded) this.collapseThinkBlock(prevBlock);
    }
    this.selectedThinkIdx = idx;
    const block = this.thinkBlocks.get(this.thinkStepOrder[idx]!);
    if (block) this.expandThinkBlock(block);
  }

  private ensureComposeCard(composeId: string): ComposeCardState | undefined {
    return this.composeCards.get(composeId);
  }

  private ensureComposeAttempt(card: ComposeCardState, attempt: number): ComposeAttemptState {
    const current = card.attempts.get(attempt);
    if (current) return current;
    const next: ComposeAttemptState = {
      attempt,
      snippet: "",
      authorDelta: "",
    };
    card.attempts.set(attempt, next);
    return next;
  }

  private createComposeCard(event: Extract<AgentEvent, { type: "compose_start" }>): ComposeCardState {
    const headerRow = styledText(this.stamp(`Compose ${event.compose_id} starting...`), chalk.cyanBright.bold);
    const bodyRow = plainText("");
    this.history.addChild(headerRow);
    this.history.addChild(bodyRow);
    const card: ComposeCardState = {
      composeId: event.compose_id,
      step: event.step,
      intent: event.intent,
      intentKind: event.intent_kind,
      claimcheckEnabled: event.claimcheck_enabled === true,
      model: event.model,
      maxAttempts: event.max_attempts,
      startedAtMs: Date.now(),
      attempts: new Map<number, ComposeAttemptState>(),
      summaryDelta: "",
      summary: "",
      expanded: true,
      headerRow,
      bodyRow,
    };
    this.composeCards.set(event.compose_id, card);
    this.composeOrder.push(event.compose_id);
    this.selectedComposeIdx = this.composeOrder.length - 1;
    return card;
  }

  private formatComposeAttemptHeader(a: ComposeAttemptState, maxAttempts: number): string {
    const check =
      a.checkPassed === true ? "✓ check passed" :
      a.checkPassed === false ? "✗ check failed" :
      "… check pending";
    return `  ${a.attempt}/${maxAttempts} ${check}`;
  }

  private composeAuthorDraft(authorDelta: string): string {
    const raw = authorDelta ?? "";
    if (raw.trim() === "") return "";
    const fence = "```ailang";
    const i = raw.indexOf(fence);
    if (i < 0) return raw;
    let body = raw.slice(i + fence.length);
    if (body.startsWith("\r\n")) body = body.slice(2);
    else if (body.startsWith("\n")) body = body.slice(1);
    const end = body.indexOf("```");
    if (end >= 0) body = body.slice(0, end);
    return body;
  }

  private applyInternalComposeDelta(streamId: string, delta: string): boolean {
    const info = parseInternalComposeStream(streamId);
    if (!info) return false;
    const card = this.ensureComposeCard(info.composeId);
    if (!card) return true;
    const attempt = this.ensureComposeAttempt(card, info.attempt);
    if (info.phase === "author") {
      attempt.authorDelta += delta;
      attempt.authorStreamSeen = true;
      this.composeFooterStatus = `subagent · ${info.composeId} · attempt ${info.attempt}/${card.maxAttempts} · authoring…`;
    } else if (info.phase === "summary") {
      card.summaryDelta += delta;
      this.composeFooterStatus = `subagent · ${info.composeId} · summarizing…`;
    } else if (info.phase === "claimcheck_informalize") {
      attempt.claimcheckInformalizeDelta = (attempt.claimcheckInformalizeDelta ?? "") + delta;
      this.composeFooterStatus = `subagent · ${info.composeId} · attempt ${info.attempt}/${card.maxAttempts} · claimcheck pass 1…`;
    } else {
      attempt.claimcheckCompareDelta = (attempt.claimcheckCompareDelta ?? "") + delta;
      this.composeFooterStatus = `subagent · ${info.composeId} · attempt ${info.attempt}/${card.maxAttempts} · claimcheck pass 2…`;
    }
    card.attempts.set(info.attempt, attempt);
    this.renderComposeCard(card);
    return true;
  }

  private renderComposeCard(card: ComposeCardState): void {
    const elapsedMs = (card.finishedAtMs ?? Date.now()) - card.startedAtMs;
    const done = typeof card.resultExitCode === "number";
    const title = done
      ? `Compose ${card.composeId} · attempts=${card.resultAttempts ?? 0} · exit=${card.resultExitCode} · ${elapsedMs}ms`
      : `Compose ${card.composeId} · model=${card.model} · max_attempts=${card.maxAttempts}`;
    card.headerRow.setText(this.stamp(chalk.cyanBright.bold(title)));

    if (!card.expanded) {
      const summaryOneLine = (card.summary || card.summaryDelta).split("\n").find((x) => x.trim().length > 0) ?? "";
      const collapsed = summaryOneLine !== "" ? `  ${summaryOneLine}` : "  ... output hidden (Ctrl+O to expand)";
      card.bodyRow.setText(this.stamp(chalk.dim(collapsed)));
      return;
    }

    const lines: string[] = [];
    lines.push(`intent: ${card.intent}`);
    if ((card.intentKind ?? "").trim() !== "") lines.push(`intent_kind: ${card.intentKind}`);
    lines.push(`sf5: ${card.claimcheckEnabled ? "enabled" : "disabled"}`);
    const attempts = Array.from(card.attempts.values()).sort((a, b) => a.attempt - b.attempt);
    for (const a of attempts) {
      lines.push(this.formatComposeAttemptHeader(a, card.maxAttempts));
      if ((a.authorDelta ?? "").trim() !== "" && a.snippet.trim() === "") {
        lines.push("    authoring draft:");
        const draft = this.composeAuthorDraft(a.authorDelta ?? "");
        const hlDraft = highlightCodeLines(draft, "ailang");
        for (const line of hlDraft) lines.push(`      ${line}`);
      }
      if (a.snippet.trim() !== "") {
        const hl = highlightCodeLines(a.snippet, "ailang");
        for (const line of hl) lines.push(`    ${line}`);
      }
      if ((a.authorToolCalls ?? []).length > 0) {
        lines.push("    author tool calls:");
        for (const l of a.authorToolCalls ?? []) lines.push(`      ${l}`);
      }
      if ((a.authorError ?? "").trim() !== "") {
        lines.push(`    author error: ${a.authorError}`);
      }
      if ((a.authorToolResults ?? []).length > 0) {
        lines.push("    author tool results:");
        for (const l of a.authorToolResults ?? []) lines.push(`      ${l}`);
      }
      if ((a.authorLedgerSnapshot ?? "").trim() !== "") {
        lines.push(`    author ledger: ${a.authorLedgerSnapshot}`);
      }
      if (a.checkPassed === false && (a.checkErrors ?? "").trim() !== "") {
        const errBox = formatHighContrastErrorBox(a.checkErrors ?? "", "    ", 5, 100);
        for (const e of errBox) lines.push(e);
      }
      if ((a.retryReason ?? "").trim() !== "") lines.push(`    retry: ${a.retryReason}`);
      if (typeof a.exitCode === "number") {
        lines.push(`    exec exit=${a.exitCode}`);
        if (this.toolOutputExpanded) {
          const out = splitOutputLines(a.stdout ?? "");
          const err = splitOutputLines(a.stderr ?? "");
          if (out.length > 0) {
            lines.push("    stdout:");
            for (const l of out) lines.push(`      ${l}`);
          }
          if (err.length > 0) {
            lines.push("    stderr:");
            for (const l of err) lines.push(`      ${l}`);
          }
        } else {
          const outLines = splitOutputLines(a.stdout ?? "").length;
          const errLines = splitOutputLines(a.stderr ?? "").length;
          lines.push(`    output hidden (stdout ${outLines} lines, stderr ${errLines} lines) (Ctrl+O to expand)`);
        }
      }
      if ((a.claimcheckInformalizeDelta ?? "").trim() !== "" && (a.claimcheckInformalization ?? "").trim() === "") {
        lines.push("    claimcheck pass1 (informalize):");
        for (const l of splitOutputLines(a.claimcheckInformalizeDelta ?? "")) lines.push(`      ${l}`);
      }
      if ((a.claimcheckInformalization ?? "").trim() !== "") {
        lines.push("    claimcheck informalization:");
        for (const l of splitOutputLines(a.claimcheckInformalization ?? "")) lines.push(`      ${l}`);
      }
      if ((a.claimcheckCompareDelta ?? "").trim() !== "" && a.claimcheckVerdict === undefined) {
        lines.push("    claimcheck pass2 (compare):");
        for (const l of splitOutputLines(a.claimcheckCompareDelta ?? "")) lines.push(`      ${l}`);
      }
      if (a.claimcheckVerdict !== undefined) {
        const verdictLine = `    claimcheck verdict=${a.claimcheckVerdict} confidence=${a.claimcheckConfidence ?? "low"} reason=${a.claimcheckReason ?? ""}`;
        if (a.claimcheckVerdict === "confirmed" || a.claimcheckVerdict === "inconclusive") {
          lines.push(verdictLine);
        } else {
          const vb = formatHighContrastErrorBox(verdictLine, "    ", 3, 100);
          for (const v of vb) lines.push(v);
        }
      }
    }
    const summary = (card.summary || card.summaryDelta).trim();
    if (summary !== "") {
      lines.push("summary:");
      for (const l of splitOutputLines(summary)) lines.push(`  ${l}`);
    }
    if (done) {
      lines.push(
        `result: attempts=${card.resultAttempts ?? 0} exit=${card.resultExitCode} truncated=${card.resultTruncated === true ? "true" : "false"}`,
      );
      try {
        const t = JSON.parse(card.telemetryJson ?? "") as Record<string, unknown>;
        const sf5 = (t.sf5 ?? null) as Record<string, unknown> | null;
        if (sf5) {
          const inv = Number(sf5.invocations ?? 0);
          const verdicts = (sf5.verdicts ?? {}) as Record<string, unknown>;
          const confirmed = Number(verdicts.confirmed ?? 0);
          const disputed = Number(verdicts.disputed ?? 0);
          const vacuous = Number(verdicts.vacuous ?? 0);
          const narrow = Number(verdicts.surprising_restriction ?? 0);
          const inconclusive = Number(verdicts.inconclusive ?? 0);
          if (inv === 0) {
            lines.push("sf5 status: NOT RUN (enable with AILANG_COMPOSE_CLAIMCHECK=1 for analyze intents)");
          } else if (disputed === 0 && vacuous === 0 && narrow === 0) {
            lines.push(`sf5 status: PASS (invocations=${inv}, confirmed=${confirmed}, inconclusive=${inconclusive})`);
          } else {
            lines.push(
              `sf5 status: ISSUES (invocations=${inv}, disputed=${disputed}, vacuous=${vacuous}, surprising_restriction=${narrow}, confirmed=${confirmed}, inconclusive=${inconclusive})`,
            );
          }
        }
      } catch {
        // Ignore telemetry parse errors in UI.
      }
      if ((card.telemetryJson ?? "").trim() !== "") lines.push(`telemetry: ${card.telemetryJson}`);
    }
    card.bodyRow.setText(this.stamp(lines.join("\n")));
  }

  private toolPreviewWidth(): number {
    const columns = process.stdout.columns || 80;
    return Math.max(20, columns - STAMP_PREFIX_WIDTH);
  }

  private clearPendingToolRowRefresh(key: string): void {
    const timer = this.pendingToolRenderTimers.get(key);
    if (!timer) return;
    clearTimeout(timer);
    this.pendingToolRenderTimers.delete(key);
  }

  private scheduleToolRowRefresh(key: string): void {
    if (this.pendingToolRenderTimers.has(key)) return;
    const last = this.lastToolRenderMs.get(key) ?? 0;
    const waitMs = Math.max(1, TOOL_RENDER_COALESCE_MS - (Date.now() - last));
    const timer = setTimeout(() => {
      this.pendingToolRenderTimers.delete(key);
      this.lastToolRenderMs.set(key, Date.now());
      this.refreshToolDetailRow(key);
      this.tui.requestRender();
    }, waitMs);
    this.pendingToolRenderTimers.set(key, timer);
  }

  private setToolRowDetails(key: string, next: ToolRowDetails, forceVisualRefresh = false): void {
    this.toolRowDetails.set(key, next);
    const now = Date.now();
    const shouldCoalesce = !forceVisualRefresh && shouldCoalesceToolRowRender(
      this.lastToolRenderMs.get(key),
      now,
      next.status,
      TOOL_RENDER_COALESCE_MS,
    );
    if (shouldCoalesce) {
      this.scheduleToolRowRefresh(key);
      return;
    }
    this.clearPendingToolRowRefresh(key);
    this.lastToolRenderMs.set(key, now);
    this.refreshToolDetailRow(key);
  }

  private refreshToolDetailRow(key: string): void {
    const detailRow = this.toolDetailRows.get(key);
    if (!detailRow) return;
    const details = this.toolRowDetails.get(key);
    if (!details) {
      detailRow.setText("");
      return;
    }
    const lines = formatToolDetailLines(
      details,
      this.toolOutputExpanded,
      this.toolPreviewWidth(),
      { toolName: this.toolRowToolNames.get(key) },
    );
    detailRow.setText(lines.length > 0 ? this.stamp(lines.join("\n")) : "");
  }

  private refreshAllToolDetailRows(): void {
    for (const key of this.toolDetailRows.keys()) {
      this.refreshToolDetailRow(key);
    }
  }

  private applyNativeToolResults(requestId: string, results: NativeToolResult[]): void {
    const usesPlannedTimeline = this.requestsUsingPlannedTimeline.has(requestId);
    let header = this.toolBatchHeaders.get(requestId);
    if (!header) {
      header = styledText(this.stamp(formatToolHeaderDone(requestId, results.length)), chalk.dim);
      this.history.addChild(header);
      this.toolBatchHeaders.set(requestId, header);
    } else {
      header.setText(this.stamp(formatToolHeaderDone(requestId, results.length)));
    }
    for (const r of results) {
      const normalized = this.normalizeToolCallId((r as { tool_call_id?: string }).tool_call_id);
      const key = this.toolKey(requestId, normalized.id);
      const plannedKey = this.runtimeToPlannedKey.get(key);
      if (usesPlannedTimeline && plannedKey) {
        this.setPlannedToolStatus(plannedKey, r.exit_code === 0 ? "done" : "error");
        this.setToolRowDetails(plannedKey, {
          status: r.exit_code === 0 ? "done" : "failed",
          stdout: r.stdout ?? "",
          stderr: r.stderr ?? "",
          truncated: r.truncated ?? false,
          exitCode: r.exit_code,
        });
        continue;
      }
      const row = this.toolRows.get(key);
      const metaBase = this.toolRowMeta.get(key) ?? normalized.id;
      const meta = this.appendMissingIdWarning(metaBase, normalized.missing);
      const status = r.exit_code === 0 ? "done" : "failed";
      if (row) {
        row.setText(this.stamp(this.renderToolRowLine(key, status, meta, r.exit_code, r.truncated ?? false)));
      } else {
        const newRow = plainText(this.stamp(this.renderToolRowLine(key, status, meta, r.exit_code, r.truncated ?? false)));
        const detailRow = plainText("");
        this.history.addChild(newRow);
        this.history.addChild(detailRow);
        this.toolRows.set(key, newRow);
        this.toolDetailRows.set(key, detailRow);
        this.toolRowToolNames.set(key, "unknown");
      }
      this.toolRowMeta.set(key, meta);
      this.setToolRowDetails(key, {
        status,
        stdout: r.stdout ?? "",
        stderr: r.stderr ?? "",
        truncated: r.truncated ?? false,
        exitCode: r.exit_code,
      });
    }
    this.updateReadFileGroupHeader(requestId);
    if (this.missingNativeRequestId === requestId) this.missingNativeRequestId = null;
  }

  private stripToolJsonBlocks(text: string): string {
    const toRemove: Array<{ start: number; end: number }> = [];
    for (const { openStart, body, closeEnd } of this.jsonFenceBlocks(text)) {
      if (this.isLikelyToolCallBody(body)) {
        toRemove.push({ start: openStart, end: closeEnd });
      }
    }
    let result = text;
    for (let i = toRemove.length - 1; i >= 0; i--) {
      const { start, end } = toRemove[i]!;
      result = result.slice(0, start) + result.slice(end);
    }
    return stripLikelyInlineToolBlob(result);
  }

  private addThinkBlock(step: number, rawContent: string): void {
    const thinkContent = rawContent.trim();
    if (!thinkContent) return;
    if (this.thinkBlocks.has(step)) return;
    const charCount = thinkContent.length;
    const headerRow = styledText(
      this.renderThinkHeader(step, charCount, false),
      chalk.reset,
    );
    const bodyRow = styledText("", chalk.reset);
    this.history.addChild(headerRow);
    this.history.addChild(bodyRow);
    this.thinkBlocks.set(step, { step, content: thinkContent, charCount, headerRow, bodyRow, expanded: false });
    this.thinkStepOrder.push(step);
  }

  // addReasoningBlock renders a side-panel block for API-level reasoning
  // (M-AI-STEP-STREAMING-THINKING v0.18.8). Distinguished visually from
  // addThinkBlock by a [reason] label so users can tell tag-convention
  // reasoning (parsed from <thinking>...</thinking> in content) apart
  // from native API thinking surfaced via the new ThinkingDelta variant.
  // Both flow into the same expandable-row UI pattern; reuses the
  // think-block infrastructure but namespaces by step+suffix.
  private addReasoningBlock(step: number, rawContent: string): void {
    const reasoningContent = rawContent.trim();
    if (!reasoningContent) return;
    // Use a distinct map key (step + 0.5 offset) so addReasoningBlock and
    // addThinkBlock can both fire for the same step without colliding.
    // Step values from AILANG are integers, so non-integer keys are safe.
    const key = step + 0.5;
    if (this.thinkBlocks.has(key)) return;
    const charCount = reasoningContent.length;
    const headerRow = styledText(
      this.renderReasoningHeader(step, charCount, false),
      chalk.reset,
    );
    const bodyRow = styledText("", chalk.reset);
    this.history.addChild(headerRow);
    this.history.addChild(bodyRow);
    this.thinkBlocks.set(key, { step: key, content: reasoningContent, charCount, headerRow, bodyRow, expanded: false });
    this.thinkStepOrder.push(key);
  }

  private renderReasoningHeader(step: number, charCount: number, expanded: boolean): string {
    const marker = expanded ? "▾" : "▸";
    return [
      chalk.dim(`[${formatTimestamp()}]   `),
      chalk.cyan("[reason]"),
      chalk.dim(` step ${step} · ${charCount} chars  ${marker}  ^r`),
    ].join("");
  }

  private renderThinkHeader(step: number, charCount: number, expanded: boolean): string {
    const marker = expanded ? "▾" : "▸";
    return [
      chalk.dim(`[${formatTimestamp()}]   `),
      chalk.magenta("[think]"),
      chalk.dim(` step ${step} · ${charCount} chars  ${marker}  ^t`),
    ].join("");
  }

  private renderThinkContent(content: string): string {
    return this.renderThinkingSegments(stripThinkTags(content), false);
  }

  private plannedToolKey(step: number, identity: string): string {
    return `${step}:${identity}`;
  }

  private renderStreamingVisibleText(raw: string): string {
    // Live render: hide the BODY of any <thinking>...</thinking> block
    // (closed or open). The full content stays in the underlying
    // streamBuffer for the thinking_stream_end final-render path which
    // splits via extractTaggedThinkAnswer. Without this, thinking-mode
    // models like glm-5 leak reasoning into the visible stream until
    // </thinking> closes.
    return this.renderThinkingSegments(stripThinkBlocksForLive(raw), true);
  }

  private renderThinkingSegments(raw: string, trimForLive: boolean): string {
    const segmented = segmentStreamMarkdown(raw);
    const trimmed = trimForLive
      ? trimSegmentsForLiveRender(segmented, STREAM_VISIBLE_MAX_CHARS)
      : { segments: segmented, truncated: false };
    const lines: string[] = [];
    if (trimmed.truncated) lines.push(chalk.dim("[stream tail]"));
    for (const seg of trimmed.segments) {
      if (seg.kind === "json_bare") {
        const confidence = this.toolEnvelopeConfidence(seg.text);
        if (this.shouldHideToolJsonSegment(confidence, seg.text)) {
          lines.push(chalk.dim("[tool json hidden; see Planned Tools]"));
          continue;
        }
        lines.push(...highlightJsonLines(seg.text));
        continue;
      }
      if (seg.kind === "plain") {
        lines.push(chalk.dim(seg.text));
        continue;
      }
      const jsonLang = normalizeJsonLang(seg.lang);
      const isJson = jsonLang === "json";
      if (isJson) {
        const confidence = this.toolEnvelopeConfidence(seg.text);
        if (this.shouldHideToolJsonSegment(confidence, seg.text)) {
          lines.push(chalk.dim("[tool json hidden; see Planned Tools]"));
          continue;
        }
      }
      lines.push(chalk.dim("```" + (seg.lang ?? "")));
      lines.push(...(isJson ? highlightJsonLines(seg.text) : highlightCodeLines(seg.text, seg.lang)));
      if (seg.kind === "code_complete") lines.push(chalk.dim("```"));
      else lines.push(chalk.dim("``` (streaming)"));
    }
    return lines.join("\n");
  }

  private shouldHideToolJsonSegment(confidence: ToolEnvelopeConfidence, text: string): boolean {
    if (this.showToolJsonStream) return false;
    if (confidence === "not_confident") return false;
    const lineCount = text.split("\n").length;
    const reachedPreviewBudget =
      text.length >= TOOL_JSON_PREVIEW_MIN_CHARS ||
      lineCount >= TOOL_JSON_PREVIEW_MIN_LINES;
    return reachedPreviewBudget;
  }

  private toolEnvelopeConfidence(text: string): ToolEnvelopeConfidence {
    const compact = text.trim();
    try {
      const parsed = JSON.parse(compact) as unknown;
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return "not_confident";
      const obj = parsed as { tool_calls?: unknown };
      if (!Array.isArray(obj.tool_calls)) return "not_confident";
      const hasTool = obj.tool_calls.some(
        (x) => !!x && typeof x === "object" && !Array.isArray(x) && typeof (x as { tool?: unknown }).tool === "string",
      );
      return hasTool ? "confident_strict" : "not_confident";
    } catch {
      const looksLikeToolEnvelope =
        compact.includes("\"tool_calls\"") &&
        compact.includes("\"tool\"") &&
        (compact.includes("\"id\"") || compact.includes("\"exec\""));
      return looksLikeToolEnvelope ? "confident_heuristic" : "not_confident";
    }
  }

  private clearPendingStreamRender(streamId: string): void {
    const timer = this.pendingStreamRenderTimers.get(streamId);
    if (!timer) return;
    clearTimeout(timer);
    this.pendingStreamRenderTimers.delete(streamId);
  }

  private renderStreamRowNow(streamId: string): void {
    const current = this.streamBuffers.get(streamId);
    if (!current) return;
    const row = this.streamRows.get(streamId);
    if (!row) return;
    row.setText(this.stamp(this.renderStreamingVisibleText(current.text)));
    current.lastRenderAtMs = Date.now();
  }

  private scheduleStreamRender(streamId: string): void {
    const current = this.streamBuffers.get(streamId);
    if (!current) return;
    const now = Date.now();
    const elapsed = now - current.lastRenderAtMs;
    if (elapsed >= STREAM_RENDER_THROTTLE_MS) {
      this.clearPendingStreamRender(streamId);
      this.renderStreamRowNow(streamId);
      this.tui.requestRender();
      return;
    }
    if (this.pendingStreamRenderTimers.has(streamId)) return;
    const wait = Math.max(1, STREAM_RENDER_THROTTLE_MS - elapsed);
    const timer = setTimeout(() => {
      this.pendingStreamRenderTimers.delete(streamId);
      this.renderStreamRowNow(streamId);
      this.tui.requestRender();
    }, wait);
    this.pendingStreamRenderTimers.set(streamId, timer);
  }

  private ensurePlannedHeader(step: number): void {
    if (this.plannedToolHeaders.has(step)) return;
    const header = styledText(this.stamp(`[planned] step-${step} Planned Tools (streaming)`), chalk.dim);
    this.history.addChild(header);
    this.plannedToolHeaders.set(step, header);
    this.plannedToolOrderByStep.set(step, []);
  }

  private upsertPlannedTool(step: number, identity: string, meta: string, status: PlannedToolStatus): string {
    this.ensurePlannedHeader(step);
    const key = this.plannedToolKey(step, identity);
    const existing = this.plannedToolEntries.get(key);
    if (existing) {
      existing.meta = meta;
      existing.status = status;
      existing.row.setText(this.stamp(formatPlannedToolRow(status, meta)));
      this.toolRowMeta.set(key, meta);
      return key;
    }
    const row = plainText(this.stamp(formatPlannedToolRow(status, meta)));
    const detailRow = plainText("");
    this.history.addChild(row);
    this.history.addChild(detailRow);
    this.plannedToolEntries.set(key, {
      step,
      identity,
      meta,
      status,
      row,
      detailRow,
      requestIds: new Set<string>(),
    });
    this.toolRows.set(key, row);
    this.toolDetailRows.set(key, detailRow);
    this.toolRowMeta.set(key, meta);
    this.toolRowKinds.set(key, "default");
    const order = this.plannedToolOrderByStep.get(step) ?? [];
    order.push(key);
    this.plannedToolOrderByStep.set(step, order);
    return key;
  }

  private setPlannedToolStatus(key: string, status: PlannedToolStatus): void {
    const entry = this.plannedToolEntries.get(key);
    if (!entry) return;
    entry.status = status;
    entry.row.setText(this.stamp(formatPlannedToolRow(status, entry.meta)));
  }

  private syncPlannedToolsFromStream(step: number, text: string): void {
    const snap = extractToolPlanSnapshot(text, TOOL_PLAN_PARSE_MAX_BYTES);
    const calls = snap.calls;
    if (calls.length === 0) return;
    this.ensurePlannedHeader(step);
    for (let i = 0; i < calls.length; i++) {
      const call = calls[i]!;
      const identity = canonicalToolIdentity(call, i);
      const meta = renderToolCallMetaWithFallback(call, (message) => this.addActivity(message));
      const key = this.plannedToolKey(step, identity);
      if (this.plannedToolEntries.has(key)) {
        const existing = this.plannedToolEntries.get(key)!;
        existing.meta = meta;
        existing.row.setText(this.stamp(formatPlannedToolRow(existing.status, existing.meta)));
      } else {
        this.upsertPlannedTool(step, identity, meta, "planned");
      }
    }
    if (snap.truncatedForParse) {
      const header = this.plannedToolHeaders.get(step);
      if (header) {
        header.setText(this.stamp(`[planned] step-${step} Planned Tools (streaming) [parse-truncated]`));
      }
    }
  }

  private markPlannedForRequestOnQueue(requestId: string, calls: DelegatedCall[]): boolean {
    const step = stepFromRequestId(requestId);
    if (step === null) return false;
    const order = this.plannedToolOrderByStep.get(step);
    if (!order || order.length === 0) return false;
    const seenForStep = new Set<string>();
    for (let i = 0; i < calls.length; i++) {
      const call = calls[i]!;
      const normalized = this.normalizeToolCallId((call as { id?: string }).id);
      const runtimeKey = this.toolKey(requestId, normalized.id);
      const identity = canonicalToolIdentity(call, i);
      const plannedKey = this.plannedToolKey(step, identity);
      if (this.plannedToolEntries.has(plannedKey)) {
        this.runtimeToPlannedKey.set(runtimeKey, plannedKey);
        this.plannedToolEntries.get(plannedKey)!.requestIds.add(requestId);
        this.toolRowToolNames.set(plannedKey, call.tool ?? "unknown");
        seenForStep.add(plannedKey);
        continue;
      }
      const meta = renderToolCallMetaWithFallback(
        normalized.missing ? { ...call, id: normalized.id } : call,
        (message) => this.addActivity(message),
      );
      const runtimeOnlyKey = this.upsertPlannedTool(step, identity, meta, "runtime_only");
      this.runtimeToPlannedKey.set(runtimeKey, runtimeOnlyKey);
      this.plannedToolEntries.get(runtimeOnlyKey)!.requestIds.add(requestId);
      this.toolRowToolNames.set(runtimeOnlyKey, call.tool ?? "unknown");
      seenForStep.add(runtimeOnlyKey);
    }
    for (const key of order) {
      const entry = this.plannedToolEntries.get(key);
      if (!entry || entry.status !== "planned") continue;
      if (!seenForStep.has(key)) this.setPlannedToolStatus(key, "filtered");
    }
    return true;
  }

  private toolKey(requestId: string, toolCallId: string): string {
    return `${requestId}:${toolCallId}`;
  }

  private normalizeRequestId(requestId: string | undefined): string {
    if (typeof requestId === "string" && requestId.trim().length > 0) return requestId;
    this.unknownRequestCounter += 1;
    return `unknown:${this.unknownRequestCounter}`;
  }

  private resolveRequestIdForEvent(
    eventType: "tool_calls" | "tool_results" | "native_tool_calls" | "native_tool_results",
    requestId: string | undefined,
  ): string {
    if (typeof requestId === "string" && requestId.trim().length > 0) {
      if (eventType === "tool_calls" || eventType === "tool_results") this.missingDelegatedRequestId = null;
      if (eventType === "native_tool_calls" || eventType === "native_tool_results") this.missingNativeRequestId = null;
      return requestId;
    }

    if (eventType === "tool_calls") {
      const id = this.normalizeRequestId(undefined);
      this.missingDelegatedRequestId = id;
      return id;
    }
    if (eventType === "tool_results") {
      if (this.missingDelegatedRequestId) return this.missingDelegatedRequestId;
      if (this.activeToolRequestId) return this.activeToolRequestId;
      const id = this.normalizeRequestId(undefined);
      this.missingDelegatedRequestId = id;
      return id;
    }
    if (eventType === "native_tool_calls") {
      const id = this.normalizeRequestId(undefined);
      this.missingNativeRequestId = id;
      return id;
    }
    if (this.missingNativeRequestId) return this.missingNativeRequestId;
    const id = this.normalizeRequestId(undefined);
    this.missingNativeRequestId = id;
    return id;
  }

  private normalizeToolCallId(toolCallId: string | undefined): { id: string; missing: boolean } {
    if (typeof toolCallId === "string" && toolCallId.trim().length > 0) {
      return { id: toolCallId, missing: false };
    }
    this.unknownToolRowCounter += 1;
    return { id: `unknown:${this.unknownToolRowCounter}`, missing: true };
  }

  private appendMissingIdWarning(meta: string, missing: boolean): string {
    return missing ? `${meta} [warning] missing_id` : meta;
  }

  private readFileGroupKey(requestId: string): string {
    return `${requestId}:ReadFile`;
  }

  private renderToolRowLine(
    key: string,
    status: ToolRowStatus,
    meta: string,
    exitCode?: number,
    truncated = false,
    extraBadge?: string,
  ): string {
    if (this.toolRowKinds.get(key) === "readfile_group_child") {
      return colorizeStatusTags(formatGroupedReadFileChildRow(status, meta, exitCode, truncated, extraBadge));
    }
    return colorizeStatusTags(formatToolRow(status, meta, exitCode, truncated, extraBadge));
  }

  private updateReadFileGroupHeader(requestId: string): void {
    // Group headers are recomputed from child terminal states to keep updates
    // deterministic under out-of-order progress events.
    const group = this.toolGroups.get(this.readFileGroupKey(requestId));
    if (!group) return;
    let done = 0;
    let failed = 0;
    for (const key of group.childKeys) {
      const status = this.toolRowDetails.get(key)?.status;
      if (status === "done") done += 1;
      else if (status === "failed") failed += 1;
    }
    group.headerRow.setText(this.stamp(formatReadFileGroupHeader(group.total, done, failed)));
  }

  private requestToolKeys(requestId: string): string[] {
    const keys: string[] = [];
    for (const key of this.toolRows.keys()) {
      if (key.startsWith(`${requestId}:`)) keys.push(key);
    }
    return keys;
  }

  private renderToolCalls(requestId: string, calls: DelegatedCall[], trackAsActiveBatch = true): void {
    let header = this.toolBatchHeaders.get(requestId);
    if (!header) {
      header = styledText(this.stamp(formatToolHeaderQueued(requestId, calls.length)), chalk.dim);
      this.history.addChild(header);
      this.toolBatchHeaders.set(requestId, header);
    } else {
      header.setText(this.stamp(formatToolHeaderQueued(requestId, calls.length)));
    }
    const shouldGroupReadFile = shouldGroupReadFileCalls(calls);
    let readFileGroup: ToolGroupState | undefined;
    if (shouldGroupReadFile && !this.toolGroups.has(this.readFileGroupKey(requestId))) {
      const readFileCalls = calls.filter((call) => call.tool === "ReadFile");
      const groupId = this.readFileGroupKey(requestId);
      const groupHeader = plainText(this.stamp(formatReadFileGroupHeader(readFileCalls.length, 0, 0)));
      this.history.addChild(groupHeader);
      readFileGroup = {
        requestId,
        groupId,
        toolFamily: "ReadFile",
        headerRow: groupHeader,
        childKeys: [],
        total: readFileCalls.length,
      };
      this.toolGroups.set(groupId, readFileGroup);
    } else if (shouldGroupReadFile) {
      readFileGroup = this.toolGroups.get(this.readFileGroupKey(requestId));
    }
    if (trackAsActiveBatch) {
      this.activeToolRequestId = requestId;
      const existing = this.toolBatchState.get(requestId);
      this.toolBatchState.set(requestId, existing ?? {
        total: calls.length,
        running: calls.length,
        done: 0,
        failed: 0,
        active: true,
        seen: new Set<string>(),
      });
      if (existing) {
        existing.total = Math.max(existing.total, calls.length);
        existing.running = Math.max(0, existing.total - existing.done - existing.failed);
        existing.active = true;
      }
    }
    const hasPlannedTimeline = this.markPlannedForRequestOnQueue(requestId, calls);
    if (hasPlannedTimeline) {
      this.requestsUsingPlannedTimeline.add(requestId);
      return;
    }
    for (const call of calls) {
      const normalized = this.normalizeToolCallId((call as { id?: string }).id);
      const key = this.toolKey(requestId, normalized.id);
      this.toolRowToolNames.set(key, call.tool ?? "unknown");
      const isGroupedReadFile = shouldGroupReadFile && call.tool === "ReadFile" && Boolean(readFileGroup);
      const rawMeta = isGroupedReadFile
        ? readFileTargetMeta(call)
        : renderToolCallMetaWithFallback(
          normalized.missing ? { ...call, id: normalized.id } : call,
          (message) => this.addActivity(message),
        );
      const meta = this.appendMissingIdWarning(rawMeta, normalized.missing);
      this.toolRowKinds.set(key, isGroupedReadFile ? "readfile_group_child" : "default");
      if (isGroupedReadFile && readFileGroup && !readFileGroup.childKeys.includes(key)) {
        readFileGroup.childKeys.push(key);
      }
      const existingRow = this.toolRows.get(key);
      if (existingRow) {
        existingRow.setText(this.stamp(this.renderToolRowLine(key, "queued", meta)));
        this.toolRowMeta.set(key, meta);
        this.addActivity(`duplicate tool_call row kept: ${key}`);
        continue;
      }
      const row = plainText(this.stamp(this.renderToolRowLine(key, "queued", meta)));
      const detailRow = plainText("");
      this.history.addChild(row);
      this.history.addChild(detailRow);
      this.toolRows.set(key, row);
      this.toolDetailRows.set(key, detailRow);
      this.toolRowMeta.set(key, meta);
      this.setToolRowDetails(key, {
        status: "queued",
        stdout: "",
        stderr: "",
        truncated: false,
      }, true);
    }
    this.updateReadFileGroupHeader(requestId);
  }

  private applyToolResults(
    requestId: string,
    phase: "running" | "progress" | "done",
    results: DelegatedResult[],
  ): void {
    const usesPlannedTimeline = this.requestsUsingPlannedTimeline.has(requestId);
    const existingKeys = this.requestToolKeys(requestId);
    let batch = this.toolBatchState.get(requestId);
    if (!batch) {
      const inferredTotal = Math.max(existingKeys.length, results.length);
      batch = {
        total: inferredTotal,
        running: inferredTotal,
        done: 0,
        failed: 0,
        active: true,
        seen: new Set<string>(),
      };
      this.toolBatchState.set(requestId, batch);
    }

    let header = this.toolBatchHeaders.get(requestId);
    if (!header) {
      const initialHeader = phase === "done"
        ? formatToolHeaderDone(requestId, results.length)
        : formatToolHeaderRunning(requestId, batch.done, batch.total, batch.failed);
      header = styledText(this.stamp(initialHeader), chalk.dim);
      this.history.addChild(header);
      this.toolBatchHeaders.set(requestId, header);
    }

    if (phase === "running" || phase === "progress") {
      this.activeToolRequestId = requestId;
      batch.active = true;
      this.setRunState("tools_run");
      header.setText(this.stamp(formatToolHeaderRunning(requestId, batch.done, batch.total, batch.failed)));
    } else {
      header.setText(this.stamp(formatToolHeaderDone(requestId, results.length)));
    }

    if (phase === "running") {
      if (usesPlannedTimeline) {
        for (const [runtimeKey, plannedKey] of this.runtimeToPlannedKey.entries()) {
          if (!runtimeKey.startsWith(`${requestId}:`)) continue;
          this.setPlannedToolStatus(plannedKey, "running");
          const prev = this.toolRowDetails.get(plannedKey);
          this.setToolRowDetails(plannedKey, {
            status: "running",
            stdout: prev?.stdout ?? "",
            stderr: prev?.stderr ?? "",
            truncated: prev?.truncated ?? false,
            exitCode: prev?.exitCode,
          }, true);
        }
      }
      for (const [key, row] of this.toolRows.entries()) {
        if (!key.startsWith(`${requestId}:`)) continue;
        const meta = this.toolRowMeta.get(key) ?? key;
        row.setText(this.stamp(this.renderToolRowLine(key, "running", meta)));
        const prev = this.toolRowDetails.get(key);
        this.setToolRowDetails(key, {
          status: "running",
          stdout: prev?.stdout ?? "",
          stderr: prev?.stderr ?? "",
          truncated: prev?.truncated ?? false,
          exitCode: prev?.exitCode,
        }, true);
      }
      this.updateReadFileGroupHeader(requestId);
      return;
    }

    const normalizedResults = results.map((result) => {
      const normalized = this.normalizeToolCallId((result as { tool_call_id?: string }).tool_call_id);
      return {
        result: { ...result, tool_call_id: normalized.id },
        missingId: normalized.missing,
      };
    });
    batch.total = Math.max(batch.total, this.requestToolKeys(requestId).length, batch.seen.size + normalizedResults.length);

    const next = applyToolProgressCounters(
      {
        total: batch.total,
        running: batch.running,
        done: batch.done,
        failed: batch.failed,
        seen: batch.seen,
      },
      normalizedResults.map((x) => x.result),
    );
    batch.done = next.done;
    batch.failed = next.failed;
    batch.running = next.running;
    batch.seen = next.seen;

    for (const entry of normalizedResults) {
      const result = entry.result;
      const key = this.toolKey(requestId, result.tool_call_id);
      const plannedKey = this.runtimeToPlannedKey.get(key);
      if (usesPlannedTimeline && plannedKey) {
        this.setPlannedToolStatus(plannedKey, result.exit_code === 0 ? "done" : "error");
        this.setToolRowDetails(plannedKey, {
          status: result.exit_code === 0 ? "done" : "failed",
          stdout: result.stdout,
          stderr: result.stderr,
          truncated: result.truncated,
          exitCode: result.exit_code,
        });
        continue;
      }
      let row = this.toolRows.get(key);
      const metaBase = this.toolRowMeta.get(key) ?? result.tool_call_id;
      const meta = this.appendMissingIdWarning(metaBase, entry.missingId);
      const status = result.exit_code === 0 ? "done" : "failed";
      if (!row) {
        row = plainText(this.stamp(this.renderToolRowLine(key, status, meta, result.exit_code, result.truncated)));
        const detailRow = plainText("");
        this.history.addChild(row);
        this.history.addChild(detailRow);
        this.toolRows.set(key, row);
        this.toolDetailRows.set(key, detailRow);
        this.toolRowToolNames.set(key, "unknown");
        this.toolRowKinds.set(key, "default");
      }
      row.setText(this.stamp(this.renderToolRowLine(key, status, meta, result.exit_code, result.truncated)));
      this.toolRowMeta.set(key, meta);
      this.setToolRowDetails(key, {
        status,
        stdout: result.stdout,
        stderr: result.stderr,
        truncated: result.truncated,
        exitCode: result.exit_code,
      });
    }

    if (phase === "progress") {
      header.setText(this.stamp(formatToolHeaderRunning(requestId, batch.done, batch.total, batch.failed)));
    }

    if (phase === "done") {
      const currentKeys = this.requestToolKeys(requestId);
      const expectedIds = currentKeys.map((key) => key.slice(requestId.length + 1));
      const seenIds = new Set(normalizedResults.map((entry) => entry.result.tool_call_id));
      const missingIds = computeMissingDoneResultIds(expectedIds, seenIds);
      for (const missingId of missingIds) {
        const key = this.toolKey(requestId, missingId);
        const row = this.toolRows.get(key);
        const meta = this.toolRowMeta.get(key) ?? missingId;
        if (row) {
          row.setText(this.stamp(this.renderToolRowLine(key, "failed", meta, 1, false, "[missing-result]")));
        }
        this.setToolRowDetails(key, {
          status: "failed",
          stdout: "",
          stderr: "missing result in done phase",
          truncated: false,
          exitCode: 1,
        }, true);
      }
      batch.active = false;
      batch.running = 0;
      if (this.activeToolRequestId === requestId) {
        this.activeToolRequestId = null;
      }
      if (usesPlannedTimeline) {
        const seenRuntime = new Set(
          normalizedResults.map((entry) => this.toolKey(requestId, entry.result.tool_call_id)),
        );
        for (const [runtimeKey, plannedKey] of this.runtimeToPlannedKey.entries()) {
          if (!runtimeKey.startsWith(`${requestId}:`)) continue;
          if (seenRuntime.has(runtimeKey)) continue;
          const current = this.plannedToolEntries.get(plannedKey)?.status;
          if (current === "running" || current === "planned") {
            this.setPlannedToolStatus(plannedKey, "planned_unexecuted");
          }
        }
      }
      this.setRunState("thinking");
      this.appendHistoryStyled("Tool results received. Continuing reasoning...", chalk.dim);
      if (this.missingDelegatedRequestId === requestId) this.missingDelegatedRequestId = null;
    }
    this.updateReadFileGroupHeader(requestId);
  }

  setAwaitingTask(waiting: boolean): void {
    this.awaitingTask = waiting;
    if (waiting) this.setRunState("idle");
    this.updateStatus();
  }

  // ---------------------------------------------------------------------------
  // Command parsing
  // ---------------------------------------------------------------------------

  private handleCommand(value: string): void {
    const parsed = parseSlashCommand(value);
    if (parsed) {
      const ctx: SlashCommandHandlerCtx = { ui: this, runtimeProcess: this.runtimeProcess };
      parsed.cmd.execute(parsed.args, ctx);
      return;
    }

    // Before any task has started, treat the first plain-text submission as the task.
    if (this.awaitingTask && value && !value.startsWith("/")) {
      this.awaitingTask = false;
      this.appendHistoryStyled(`> ${value}`, chalk.cyan);
      this.tui.requestRender();
      this.onInitialTask?.(value);
      return;
    }

    // After task completion, plain text (not starting with '/') is a follow-up.
    if (this.taskDone && value && !value.startsWith("/")) {
      this.appendHistoryStyled(`> ${value}`, chalk.cyan);
      this.onUserMessage?.(value);
      // Reset taskDone — runtime process is now processing again; next done re-enables it.
      this.taskDone = false;
      this.setRunState("thinking");
      this.appendHistoryStyled("Runtime is reasoning...", chalk.dim);
      this.tui.requestRender();
      return;
    }

    if (shouldLockPlainInput(this.awaitingTask, this.taskDone, value)) {
      this.appendHistoryStyled("Input locked: task still running. Use /abort to stop.", chalk.dim);
      this.tui.requestRender();
      return;
    }

    if (value) {
      this.appendHistoryStyled(`Unknown command: "${value}". Try /model, /abort, or type a follow-up after the task is done.`, chalk.dim);
      this.tui.requestRender();
    }
  }
  // ---------------------------------------------------------------------------
  // Public helpers — called by commands.ts
  // ---------------------------------------------------------------------------

  private readonly styleMap = new Map<string, (s: string) => string>([
    ["dim", chalk.dim],
    ["red", chalk.red],
    ["green", chalk.green],
    ["cyan", chalk.cyan],
  ]);

  /**
   * Append a styled line to the history pane.
   * Recognised `style` names: "dim", "red", "green", "cyan".
   */
  addHistoryText(text: string, style?: string): void {
    const fn = this.styleMap.get(style ?? "");
    if (fn) this.appendHistoryStyled(text, fn);
    else this.appendHistoryPlain(text);
    this.tui.requestRender();
  }

  /**
   * Switch to a new model — fires onModelChange callback.
   * Public so commands.ts can call it from the /model handler.
   */
  switchModel(model: string): void {
    this.model = model;
    this.appendHistoryStyled(`Model → ${model}`, chalk.cyan.dim);
    this.onModelChange?.(model);
    this.updateStatus();
    this.tui.requestRender();
  }
  private openPickerWithModels(models: string[]): void {
    const items: SelectItem[] = models.map((m) => ({
      value: m,
      label: m,
    }));

    const list = new SelectList(items, 10, SELECT_THEME);

    list.onSelect = (item: SelectItem) => {
      this.overlayHandle?.hide();
      this.overlayHandle = null;
      this.switchModel(item.value);
    };

    list.onCancel = () => {
      this.overlayHandle?.hide();
      this.overlayHandle = null;
      this.tui.requestRender();
    };

    this.overlayHandle = this.tui.showOverlay(list, {
      width: "60%",
      maxHeight: "50%",
    });
  }


  /**
   * Open the model-picker SelectList overlay.
   * Public so commands.ts can call it from the /model handler (no args).
   */
  showModelPicker(): void {
    // Dismiss any existing overlay first.
    this.overlayHandle?.hide();
    this.overlayHandle = null;

    fetchDynamicModelsFromEnv().then((models) => {
      this.openPickerWithModels(models);
    });
  }



  // ---------------------------------------------------------------------------
  // Status bar
  // ---------------------------------------------------------------------------

  private updateStatus(): void {
    const previewWidth = this.toolPreviewWidth();
    if (previewWidth !== this.lastToolPreviewWidth) {
      this.lastToolPreviewWidth = previewWidth;
      this.refreshAllToolDetailRows();
    }
    const now = Date.now();
    const elapsedSec = Math.floor((now - this.waitState.sinceMs) / 1000);
    const sinceUpdateSec = Math.floor((now - this.lastUpdateMs) / 1000);
    const lastUpdateTs = formatTimestamp(new Date(this.lastUpdateMs));
    const spinner = isWaitingState(this.waitState.state) ? ["|", "/", "-", "\\"][this.spinnerFrame] : "";
    const activeBatch = this.activeToolRequestId ? this.toolBatchState.get(this.activeToolRequestId) : undefined;
    const toolsText = activeBatch && activeBatch.active
      ? ` | tools: ${activeBatch.done}/${activeBatch.total} failed=${activeBatch.failed}`
      : "";
    const spinnerPrefix = spinner ? `${spinner} ` : "";
    const composeText = this.composeFooterStatus !== "" ? ` | ${this.composeFooterStatus}` : "";
    const line1 = `[λ] ${spinnerPrefix}state: ${this.waitState.state} | step ${this.step} | elapsed: ${elapsedSec}s | last update: ${sinceUpdateSec}s ago | at: ${lastUpdateTs}${toolsText}${composeText}`;
    const extPart = this.loadedExtensions !== "" ? ` | ext: ${this.loadedExtensions}` : "";
    const line2Base = `    model: ${this.model || "—"}${this.branch ? ` | branch: ${this.branch}` : ""}${extPart}`;
    const stateColor =
      this.waitState.state === "thinking" ? ((s: string) => chalk.blueBright.bold(s)) :
      (this.waitState.state === "tools_wait" || this.waitState.state === "tools_run") ? chalk.yellow :
      this.waitState.state === "error" ? chalk.red :
      ((s: string) => chalk.greenBright.bold(s));
    let line2 = stateColor(line2Base);
    if (this.latestContextUsage) {
      const { tokensEst, limit } = this.latestContextUsage;
      const ctxText = ` | ${formatContextUsage(tokensEst, limit)}`;
      line2 += colorizeContextUsageSegment(ctxText, tokensEst, limit, stateColor);
    }
    this.statusBar.setText(`${stateColor(line1)}\n${line2}`);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  stop(): void {
    clearInterval(this.statusTick);
    for (const timer of this.pendingToolRenderTimers.values()) {
      clearTimeout(timer);
    }
    this.pendingToolRenderTimers.clear();
    for (const timer of this.pendingStreamRenderTimers.values()) {
      clearTimeout(timer);
    }
    this.pendingStreamRenderTimers.clear();
    this.overlayHandle?.hide();
    this.tui.stop();
  }
}
