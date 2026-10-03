import { theme } from "./theme.js";

function splitLines(text: string): string[] {
  return text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
}

function highlightJsonLine(line: string): string {
  let out = "";
  let i = 0;
  while (i < line.length) {
    const ch = line[i]!;
    if (ch === '"') {
      let j = i + 1;
      let escaped = false;
      while (j < line.length) {
        const c = line[j]!;
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
        if (c === '"') {
          j += 1;
          break;
        }
        j += 1;
      }
      let k = j;
      while (k < line.length && /\s/.test(line[k]!)) k += 1;
      const isKey = k < line.length && line[k] === ":";
      out += isKey ? theme.cyanBright(line.slice(i, j)) : theme.green(line.slice(i, j));
      i = j;
      continue;
    }
    if (/[0-9-]/.test(ch)) {
      let j = i + 1;
      while (j < line.length && /[0-9eE+.-]/.test(line[j]!)) j += 1;
      out += theme.magentaBright(line.slice(i, j));
      i = j;
      continue;
    }
    if (line.startsWith("true", i) || line.startsWith("false", i) || line.startsWith("null", i)) {
      const token = line.startsWith("true", i)
        ? "true"
        : line.startsWith("false", i)
          ? "false"
          : "null";
      out += theme.yellowBright(token);
      i += token.length;
      continue;
    }
    if ("{}[]:,".includes(ch)) {
      out += theme.gray(ch);
      i += 1;
      continue;
    }
    out += ch;
    i += 1;
  }
  return out;
}

export function highlightJsonLines(text: string): string[] {
  return splitLines(text).map((line) => highlightJsonLine(line));
}

