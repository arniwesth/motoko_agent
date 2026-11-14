// make_fixed_twins.ts <tree> <dest> — NEGATIVE CONTROL ONLY. Writes to <dest>/src/tui/src/ a
// copy of compose-claimcheck.ts, and env-server.ts's truncateUtf8ByBytes alone, in which the
// cut backs off to a character boundary before Buffer.toString. check.ts run with <dest> as
// its tree must then find 0 violations of X-4 and X-2; run on the real tree it finds them.
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { join } from "path";
const [tree, dest] = process.argv.slice(2);
const helper = `  function __cut(b: Buffer, maxBytes: number): number {
    let cut = Math.max(0, Math.min(maxBytes, b.byteLength));
    if (cut < b.byteLength) while (cut > 0 && (b[cut] & 0xc0) === 0x80) cut--;
    return cut;
  }
`;
function fix(src: string): string {
  const a = 'b.subarray(0, Math.max(0, maxBytes)).toString("utf8")';
  const g = "  if (b.byteLength <= maxBytes) return";
  if (!src.includes(a) || !src.includes(g)) throw new Error("twin text not as expected; control not applicable");
  return src.replace(a, 'b.subarray(0, __cut(b, maxBytes)).toString("utf8")').replace(g, helper + g);
}
mkdirSync(join(dest, "src/tui/src"), { recursive: true });
writeFileSync(join(dest, "src/tui/src/compose-claimcheck.ts"), fix(readFileSync(join(tree, "src/tui/src/compose-claimcheck.ts"), "utf8")));
const env = readFileSync(join(tree, "src/tui/src/env-server.ts"), "utf8").split("\n");
const s = env.findIndex((l) => l.startsWith("function truncateUtf8ByBytes("));
let e = s; while (env[e] !== "}") e++;
writeFileSync(join(dest, "src/tui/src/env-server.ts"), fix(env.slice(s, e + 1).join("\n")) + "\n");
