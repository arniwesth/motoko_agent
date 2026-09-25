// 031 PLAN-001 P1.2b probe stand-in for a Node bridge (mcp-call.mjs / context-mode-mcp-call.mjs).
// Synthetic: talks to nothing. Appends its argv to $P12B_CALLS_LOG, then prints one JSON object
// whose "output" is the argv followed by 3000 padding characters, so a caller's max_output_chars
// is visible as truncation.
import { appendFileSync } from "node:fs";
const argv = process.argv.slice(2).join(" ");
if (process.env.P12B_CALLS_LOG) appendFileSync(process.env.P12B_CALLS_LOG, argv + "\n");
process.stdout.write(JSON.stringify({ output: "ARGV " + argv + " PAD " + "x".repeat(3000) }) + "\n");
