// nan_cap.ts — an observation outside the registered properties (SUMMARY.md, "Observations").
// env-server.ts:1507 computes the claimcheck cap as
//   Math.max(1, Number(process.env.AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES ?? 4000))
// and a non-numeric value gives NaN, which runClaimCheck passes on through Math.max(1, NaN).
// This runs the real runClaimCheck with that cap for a few env spellings and prints what the
// informalizer would be shown. Exit 1 if any spelling drops the whole certificate.
//
//   bun nan_cap.ts        (from the tree root)
import { loadRunClaimCheck } from "../twins.ts";
const rc = await loadRunClaimCheck(process.cwd());
let dropped = false;
for (const env of ["4000", "4k", "4_000", " 4000 ", ""]) {
  const cap = Math.max(1, Number(env ?? 4000)); // env-server.ts:1507, verbatim but for the env read
  const r = await rc("certificate text", cap);
  console.log(`${JSON.stringify(env).padEnd(9)} cap=${String(cap).padEnd(5)} -> ${JSON.stringify(r)}`);
  if (r.text === "" && r.truncated) dropped = true;
}
process.exit(dropped ? 1 : 0);
