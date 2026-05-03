export type StreamSegmentKind = "plain" | "code_complete" | "code_open" | "json_bare";

export interface StreamSegment {
  kind: StreamSegmentKind;
  lang?: string;
  text: string;
  stableKey: string;
}

export interface TrimmedStreamSegments {
  segments: StreamSegment[];
  truncated: boolean;
}

function isLineFenceAt(text: string, idx: number): boolean {
  if (idx < 0 || idx + 3 > text.length) return false;
  if (!(text[idx] === "`" && text[idx + 1] === "`" && text[idx + 2] === "`")) return false;
  return idx === 0 || text[idx - 1] === "\n";
}

export function normalizeJsonLang(lang?: string): string | undefined {
  const normalized = (lang ?? "").trim().toLowerCase();
  if (normalized === "json" || normalized === "jsonc" || normalized === "application/json") return "json";
  return undefined;
}

function readFenceLang(text: string, openIdx: number): { lang?: string; bodyStart: number } {
  let i = openIdx + 3;
  let lineEnd = text.indexOf("\n", i);
  if (lineEnd < 0) lineEnd = text.length;
  const raw = text.slice(i, lineEnd).trim();
  const token = raw.split(/\s+/).filter(Boolean)[0];
  const lang = token && /^[A-Za-z0-9_-]+$/.test(token) ? token.toLowerCase() : undefined;
  const bodyStart = lineEnd < text.length ? lineEnd + 1 : lineEnd;
  return { lang, bodyStart };
}

function findNextLineFence(text: string, from: number): number {
  let i = Math.max(0, from);
  while (i < text.length) {
    const n = text.indexOf("```", i);
    if (n < 0) return -1;
    if (isLineFenceAt(text, n)) return n;
    i = n + 3;
  }
  return -1;
}

function splitPlainIntoBareJsonSegments(text: string, segStart: number): { segments: StreamSegment[]; nextSeg: number } {
  const out: StreamSegment[] = [];
  let seg = segStart;
  let i = 0;

  while (i < text.length) {
    const brace = text.indexOf("{", i);
    if (brace < 0) {
      const tail = text.slice(i);
      if (tail.length > 0) out.push({ kind: "plain", text: tail, stableKey: `s${seg++}:plain` });
      break;
    }
    if (brace > i) out.push({ kind: "plain", text: text.slice(i, brace), stableKey: `s${seg++}:plain` });

    let j = brace;
    let depth = 0;
    let inStr = false;
    let escaped = false;
    let closed = false;
    while (j < text.length) {
      const ch = text[j]!;
      if (escaped) {
        escaped = false;
        j += 1;
        continue;
      }
      if (inStr) {
        if (ch === "\\") escaped = true;
        else if (ch === '"') inStr = false;
        j += 1;
        continue;
      }
      if (ch === '"') {
        inStr = true;
        j += 1;
        continue;
      }
      if (ch === "{") depth += 1;
      else if (ch === "}") {
        depth -= 1;
        if (depth === 0) {
          j += 1;
          closed = true;
          break;
        }
      }
      j += 1;
    }

    const candidate = text.slice(brace, j);
    const likelyJson = candidate.includes(":") && candidate.includes('"');
    if (!likelyJson) {
      out.push({ kind: "plain", text: "{", stableKey: `s${seg++}:plain` });
      i = brace + 1;
      continue;
    }
    out.push({
      kind: "json_bare",
      lang: "json",
      text: candidate,
      stableKey: `s${seg++}:json_bare:${closed ? "complete" : "open"}`,
    });
    i = j;
  }

  return { segments: out, nextSeg: seg };
}

export function segmentStreamMarkdown(text: string): StreamSegment[] {
  const out: StreamSegment[] = [];
  let i = 0;
  let seg = 0;

  while (i < text.length) {
    const open = findNextLineFence(text, i);
    if (open < 0) {
      const tail = text.slice(i);
      if (tail.length > 0) {
        const split = splitPlainIntoBareJsonSegments(tail, seg);
        out.push(...split.segments);
        seg = split.nextSeg;
      }
      break;
    }

    if (open > i) {
      const split = splitPlainIntoBareJsonSegments(text.slice(i, open), seg);
      out.push(...split.segments);
      seg = split.nextSeg;
    }

    const { lang, bodyStart } = readFenceLang(text, open);
    const close = findNextLineFence(text, bodyStart);
    if (close < 0) {
      out.push({
        kind: "code_open",
        lang,
        text: text.slice(bodyStart),
        stableKey: `s${seg++}:code_open:${lang ?? ""}`,
      });
      break;
    }

    out.push({
      kind: "code_complete",
      lang,
      text: text.slice(bodyStart, close),
      stableKey: `s${seg++}:code_complete:${lang ?? ""}`,
    });

    let next = close + 3;
    if (text[next] === "\r") next += 1;
    if (text[next] === "\n") next += 1;
    i = next;
  }

  return out;
}

export function trimSegmentsForLiveRender(segments: StreamSegment[], maxChars: number): TrimmedStreamSegments {
  const cap = Math.max(256, maxChars);
  const total = segments.reduce((n, s) => n + s.text.length, 0);
  if (total <= cap) return { segments, truncated: false };

  let drop = total - cap;
  const kept: StreamSegment[] = [];
  for (const seg of segments) {
    if (drop <= 0) {
      kept.push(seg);
      continue;
    }
    if (seg.text.length <= drop) {
      drop -= seg.text.length;
      continue;
    }
    const chopped = seg.text.slice(drop);
    drop = 0;
    kept.push({ ...seg, text: chopped });
  }
  if (kept.length === 0) return { segments: [], truncated: true };

  const first = kept[0]!;
  kept[0] = { ...first, text: `…${first.text}` };
  return { segments: kept, truncated: true };
}
