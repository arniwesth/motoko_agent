// pin_drift.ts — X-11: the evaluator's pinned copies (src/eval/journal/digests.ail) of the T4
// functions against the CURRENT source of src/core/journal.ail. For every
// `-- SOURCE src/core/journal.ail Lx-y Ba-b sha256:H symbol=S` pin, find S's declaration in the
// current file (first line `... func S(` through the first line that is exactly `}`), hash
// those bytes (with the trailing newline, as the pin header describes) and compare with H.
// Also hashes the variant of chain_digest_over that calls `chain_step` (the body the eval copy
// carries), to test whether the pin was taken over that body. Exit 1 on any drift.
//
//   bun ../out/pin_drift.ts        (from the tree root)
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";

const src = readFileSync("src/core/journal.ail", "utf8");
const ev = readFileSync("src/eval/journal/digests.ail", "utf8");
const sha = (s: string) => createHash("sha256").update(Buffer.from(s, "utf8")).digest("hex");
const lines = src.split("\n");

function decl(sym: string): { text: string; from: number; to: number } | null {
  const i = lines.findIndex((l) => new RegExp(`func ${sym}\\(`).test(l));
  if (i < 0) return null;
  let j = i;
  while (j < lines.length && lines[j] !== "}") j++;
  return { text: lines.slice(i, j + 1).join("\n") + "\n", from: i + 1, to: j + 1 };
}

let drift = 0;
const re = /-- SOURCE src\/core\/journal\.ail L(\d+)-(\d+) B(\d+)-(\d+) sha256:([0-9a-f]{64}) symbol=(\w+)/g;
for (const m of ev.matchAll(re)) {
  const [, l0, l1, , , h, sym] = m;
  const d = decl(sym);
  if (!d) { console.log(`${sym}: NOT FOUND in current source`); drift++; continue; }
  const now = sha(d.text);
  const ok = now === h;
  if (!ok) drift++;
  console.log(`${sym.padEnd(20)} pin L${l0}-${l1}  now L${d.from}-${d.to}  ${ok ? "same bytes" : "DRIFT"}  (pin ${h.slice(0, 12)}…, now ${now.slice(0, 12)}…)`);
  if (!ok && sym === "chain_digest_over") {
    const alt = d.text.replace("List.foldl(chain_digest_after, base, ms)", "List.foldl(chain_step, base, ms)");
    console.log(`  chain_digest_over with body List.foldl(chain_step, base, ms): ${sha(alt) === h ? "MATCHES the pin" : "does not match"} (${sha(alt).slice(0, 12)}…)`);
  }
}
const ds = decl("chain_digests_over");
console.log(`chain_digests_over is not pinned by the evaluator (current L${ds?.from}-${ds?.to}); chain_step is ${/chain_step\b[^]*?chain_step\b/.test(src.replace(/pure func chain_step[^]*?\n}\n/, "")) ? "used" : "declared but unused"} in journal.ail`);
process.exit(drift > 0 ? 1 : 0);
