// strlen_check.ts <prefix> — side check: on every valid-UTF-8 case, the runtime's Str.length (printed by
// direct.sh as field 3) equals the code-point count; on invalid input it never exceeds the byte
// length. Reads <prefix>.cases and <prefix>.direct.
import { readFileSync } from "fs";
const [prefix] = process.argv.slice(2);
const cases = readFileSync(`${prefix}.cases`, "utf8").split("\n").filter(Boolean);
const out = readFileSync(`${prefix}.direct`, "utf8").split("\n").filter((l) => /^\d+\|/.test(l));
const strict = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });
let v = 0, nv = 0, bad = 0, invGtBytes = 0;
for (let i = 0; i < cases.length; i++) {
  const b = Buffer.from(cases[i].split(",")[1], "base64");
  const sl = Number(out[i].split("|")[2]);
  try { const s = strict.decode(b); v++; if ([...s].length !== sl) { bad++; if (bad < 4) console.log("mismatch", b.toString("hex"), sl); } }
  catch { nv++; if (sl > b.length) invGtBytes++; }
}
console.log({ valid: v, codepointMismatch: bad, invalid: nv, invalidStrLenGtBytes: invGtBytes });
