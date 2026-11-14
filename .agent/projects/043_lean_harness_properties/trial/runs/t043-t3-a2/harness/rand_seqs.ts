// rand_seqs.ts — seeded random action sequences for run_p31.sh's explicit-sequence mode.
//   bun rand_seqs.ts <count> <minlen> <maxlen> <seed> [alphabet size, default 14]
// Prints one JSON array of arrays. mulberry32, so a seed names the same sample everywhere.
const [count, minlen, maxlen, seed, alpha] = process.argv.slice(2).map(Number);
let s = seed >>> 0;
const rnd = () => {
  s = (s + 0x6d2b79f5) >>> 0;
  let t = s;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const a = alpha || 14;
const out: number[][] = [];
for (let i = 0; i < count; i++) {
  const n = minlen + Math.floor(rnd() * (maxlen - minlen + 1));
  out.push(Array.from({ length: n }, () => Math.floor(rnd() * a)));
}
process.stdout.write(JSON.stringify(out));
