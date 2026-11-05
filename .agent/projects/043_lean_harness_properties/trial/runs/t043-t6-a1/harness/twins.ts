// twins.ts — the REAL TypeScript twins of `truncate_utf8_by_bytes`, made callable.
//
// Both twins are module-private (`function truncateUtf8ByBytes`, not exported), so they are
// reached two ways:
//
//   1. byExtraction(file): the function's own source text, cut from the real file at run time
//      (from `function truncateUtf8ByBytes(` to the first line that is exactly `}`), transpiled
//      by Bun.Transpiler and evaluated. No edit, no model: the text that ships.
//   2. viaRunClaimCheck(s, max): compose-claimcheck.ts's twin through its exported caller
//      `runClaimCheck`, with a stub `callStream` that captures the informalizer prompt and
//      throws. The prompt ends with the certificate, which is the twin's `text`, followed by
//      `\n[truncated: N bytes omitted]` when the twin said `truncated`.

import { readFileSync } from "fs";
import { join, resolve } from "path";

export const CLAIMCHECK = "src/tui/src/compose-claimcheck.ts";
export const ENVSERVER = "src/tui/src/env-server.ts";

export function extractSource(tree: string, rel: string): string {
  const lines = readFileSync(join(tree, rel), "utf8").split("\n");
  const start = lines.findIndex((l) => l.startsWith("function truncateUtf8ByBytes("));
  if (start < 0) throw new Error(`no truncateUtf8ByBytes in ${rel}`);
  let end = start;
  while (end < lines.length && lines[end] !== "}") end++;
  if (end >= lines.length) throw new Error(`unterminated truncateUtf8ByBytes in ${rel}`);
  return lines.slice(start, end + 1).join("\n");
}

export function byExtraction(tree: string, rel: string): (s: string, max: number) => unknown {
  const ts = extractSource(tree, rel) + "\nglobalThis.__t6_twin = truncateUtf8ByBytes;\n";
  const js = new Bun.Transpiler({ loader: "ts" }).transformSync(ts);
  new Function("Buffer", js)(Buffer);
  const f = (globalThis as any).__t6_twin;
  delete (globalThis as any).__t6_twin;
  if (typeof f !== "function") throw new Error(`could not load twin from ${rel}`);
  return f;
}

export async function loadRunClaimCheck(tree: string) {
  const mod = await import(resolve(tree, CLAIMCHECK));
  const SUFFIX = /\n\[truncated: (\d+) bytes omitted\]$/;
  const MARK = "\nCertificate:\n";
  return async (s: string, max: number): Promise<{ text: string; truncated: boolean; omittedBytes: number }> => {
    let prompt: string | null = null;
    await mod.runClaimCheck({
      enabled: true, intentKind: "analyze", intent: "t6", certificateStdout: s,
      informalizerModel: "stub", comparatorModel: "stub", timeoutMs: 1000, maxInvocations: 1,
      stdoutMaxBytes: max, telemetry: mod.createClaimCheckTelemetry(),
      callStream: async (_m: string, p: string) => { prompt = p; throw new Error("t6 stub: prompt captured"); },
      emitEvent: () => {}, step: 0, composeId: "t6", attempt: 0,
    });
    if (prompt === null) throw new Error("runClaimCheck did not call the informalizer");
    const p: string = prompt;
    const cert = p.slice(p.indexOf(MARK) + MARK.length);
    const m = cert.match(SUFFIX);
    return m
      ? { text: cert.slice(0, cert.length - m[0].length), truncated: true, omittedBytes: Number(m[1]) }
      : { text: cert, truncated: false, omittedBytes: 0 };
  };
}
