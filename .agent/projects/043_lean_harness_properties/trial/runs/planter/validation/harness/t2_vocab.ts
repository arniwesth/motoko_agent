// P2.1, the TypeScript side: herdrMeansAgentGone over the same strings, same order, as t2_vocab.ail.
const tree = process.argv[2];
const { herdrMeansAgentGone } = await import(`${tree}/src/tui/src/wake-waiter.ts`);
const syms = ["a", "1", " ", "\"", "é", "€"];
const blen = (s: string) => Buffer.byteLength(s, "utf8");
const all: string[] = [];
const from = (prefix: string, budget: number): void => {
  all.push(prefix);
  for (const x of syms) if (blen(x) <= budget) from(prefix + x, budget - blen(x));
};
from("", 8);
console.log(`strings=${all.length}`);
for (const code of [-1, 0, 1, 2, 3]) {
  const g = all.filter((s) => herdrMeansAgentGone({ code, stdout: "", stderr: s }));
  console.log(`exit=${code} gone=${g.length} ${g.join("|")}`);
}
