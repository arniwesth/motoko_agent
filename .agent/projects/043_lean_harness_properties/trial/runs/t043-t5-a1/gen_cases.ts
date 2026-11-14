// gen_cases.ts — the generator half of the random test of `path_up` (src/core/journal.ail:1403).
//
//   bun gen_cases.ts <seed> <count> > cases.jsonl
//
// One JSON object per line: {"mode": <generator>, "es": [[id, parent_id, kind], ...], "start": id}.
// `kind` is "header" exactly when parent_id is "" (the root sentinel; JSON null and a missing key
// decode to "" in `journal_entry_of_json`), so the reader's `strict_path`, which also demands a
// header root, has something to accept. Deterministic in the seed (mulberry32).
//
// Generators (round-robin, so every mode gets count/7 cases):
//   graph     random small graph: 0-12 entries, ids from a small pool (so ids repeat), parents
//             "" / a pool id / a missing id; start from the pool, "", or missing
//   weird     as graph, but the pool holds awkward strings: "", " ", ",", "\"", "null", "ü", "0001"
//   chain     the host writer's shape: ids "0000".."NNNN", each parent the previous id, header
//             first; 1-60 entries; start = the leaf (what `journal_leaf` passes)
//   rootcycle chain, then the HEADER's parent_id set to the leaf (a cycle through the root)
//   backedge  chain, then one entry's parent set to a later id (a cycle above the leaf or not)
//   selfloop  chain, then one entry's parent set to its own id
//   dupid     chain, then 1-3 extra entries appended that REUSE existing ids with other parents
//             (what a writer that lost its seq counter would produce), start = the last line's id

type Spec = [string, string, string];
type Case = { mode: string; es: Spec[]; start: string };

const [seedArg, countArg] = process.argv.slice(2);
if (!seedArg || !countArg) throw new Error("usage: bun gen_cases.ts <seed> <count>");
let state = Number(seedArg) >>> 0;
const rnd = (): number => {
  state = (state + 0x6d2b79f5) >>> 0;
  let t = state;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const int = (lo: number, hi: number) => lo + Math.floor(rnd() * (hi - lo + 1)); // inclusive
const pick = <T>(xs: T[]): T => xs[Math.floor(rnd() * xs.length)];
const spec = (id: string, parent: string): Spec => [id, parent, parent === "" ? "header" : "x"];
const pad = (n: number) => String(n).padStart(4, "0");

function graph(pool: string[]): Case {
  const n = int(0, 12);
  const es: Spec[] = [];
  for (let i = 0; i < n; i++) {
    const r = rnd();
    const parent = r < 0.2 ? "" : r < 0.85 ? pick(pool) : "missing";
    es.push(spec(pick(pool), parent));
  }
  const r = rnd();
  const start = r < 0.8 ? pick(pool) : r < 0.9 ? "" : "missing";
  return { mode: "", es, start };
}

function chain(n: number): Spec[] {
  const es: Spec[] = [];
  for (let i = 0; i < n; i++) es.push(spec(pad(i), i === 0 ? "" : pad(i - 1)));
  return es;
}

const setParent = (s: Spec, p: string): Spec => [s[0], p, p === "" ? "header" : "x"];

function gen(mode: string): Case {
  switch (mode) {
    case "graph": {
      const k = int(1, 5);
      return { ...graph(["a", "b", "c", "d", "e"].slice(0, k)), mode };
    }
    case "weird":
      return { ...graph(["", " ", ",", "\"", "null", "ü", "0001", "a"]), mode };
    case "chain": {
      const es = chain(int(1, 60));
      return { mode, es, start: es[es.length - 1][0] };
    }
    case "rootcycle": {
      const es = chain(int(1, 60));
      const leaf = es[es.length - 1][0];
      es[0] = setParent(es[0], leaf);
      return { mode, es, start: leaf };
    }
    case "backedge": {
      const n = int(2, 60);
      const es = chain(n);
      const i = int(0, n - 2);
      const j = int(i + 1, n - 1);
      es[i] = setParent(es[i], pad(j));
      return { mode, es, start: rnd() < 0.7 ? es[n - 1][0] : pad(int(0, n - 1)) };
    }
    case "selfloop": {
      const n = int(1, 60);
      const es = chain(n);
      const i = int(0, n - 1);
      es[i] = setParent(es[i], pad(i));
      return { mode, es, start: es[n - 1][0] };
    }
    case "dupid": {
      const n = int(1, 40);
      const es = chain(n);
      const extra = int(1, 3);
      for (let x = 0; x < extra; x++) {
        const id = pad(int(0, n - 1));
        const r = rnd();
        const parent = r < 0.15 ? "" : r < 0.9 ? pad(int(0, n - 1)) : "missing";
        es.push(spec(id, parent));
      }
      return { mode, es, start: es[es.length - 1][0] };
    }
  }
  throw new Error(mode);
}

const modes = ["graph", "weird", "chain", "rootcycle", "backedge", "selfloop", "dupid"];
const count = Number(countArg);
const out: string[] = [];
for (let i = 0; i < count; i++) out.push(JSON.stringify(gen(modes[i % modes.length])));
process.stdout.write(out.join("\n") + "\n");
