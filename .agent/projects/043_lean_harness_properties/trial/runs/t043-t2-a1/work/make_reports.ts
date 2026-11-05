// make_reports.ts — writes ../reports.tsv. The witness column is the witness file's JSON with
// every non-ASCII character as a \u escape, so it is exact and tab/newline-free.
//
//   bun make_reports.ts
import * as fs from "fs";
import * as path from "path";

const OUT = "/home/motoko/trial-043/s/t043-t2-a1/out";
const PAIR = (p: string, id: string) => `bun ${OUT}/repro/twin_pair.ts ${p} ${OUT}/repro/witness/${id}.json`;
const wit = (id: string): string =>
  JSON.stringify(JSON.parse(fs.readFileSync(path.join(OUT, "repro/witness", `${id}.json`), "utf8"))).replace(
    /[\u007f-\uffff]/g,
    (c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, "0")}`,
  ) + " (spawnError absent)";

type R = [id: string, prop: string, route: string, claim: string, repro: string, witness: string, notes: string];
const rows: R[] = [
  [
    "A1-T2-1", "P2.1", "reading",
    "herdrMeansAgentGone tests herdrFailureCode(r).endsWith(\"_not_found\") (wake-waiter.ts:143) where means_agent_gone tests == \"agent_not_found\" (types.ail:1207), so herdr's pane_not_found envelope on exit 1 is gone=true in TS and gone=false in AILANG.",
    PAIR("P2.1", "A1-T2-1"), wit("A1-T2-1"),
    "Largest P2.1 class: 15,621 of 25,967 disagreements in run1, all gone when this line is patched (run 3) (any code ending _not_found other than agent_not_found: pane_not_found, plugin_pane_not_found, plugin_not_found, xagent_not_found, _not_found...). Also contradicts means_agent_gone's \"narrow on purpose\" and MEASUREMENTS-2026-08-31 (\"a code not seen here is by definition not evidence the agent is gone\"). pane_not_found and plugin_pane_not_found are real herdr codes in this tree: herdr.ail:818 handles pane_not_found from `pane close`, types.ail:1965 has it as a `pane get` answer, and plugin_pane_not_found was observed against a LIVE pane (HANDOFF-2026-09-02-run-file-truth-view-and-loop-guard.md:147). Whether `agent get`/`agent wait` can return them is not measured. Waiter consequence: A1-T2-2. A patched copy with === \"agent_not_found\" makes this repro exit 0.",
  ],
  [
    "A1-T2-2", "X-2", "execution",
    "Through the production waiter (defaultWakeWaiterFactory with the real runner), a claude delegate whose `herdr agent wait` exits 1 with error.code pane_not_found is replied outcome=lost instead of host_error, with a detail that says \"herdr reports agent_not_found\".",
    `bun ${OUT}/repro/x2_waiter_outcome.ts pane_not_found`,
    "herdr stub via HERDR_BIN_PATH: `agent get w1:p1` -> exit 0, ROW agent_info on stdout; `agent wait w1:p1 --until idle --until done --until blocked` -> exit 1, stderr {\"error\":{\"code\":\"pane_not_found\",\"message\":\"x\"},\"id\":\"cli:agent:wait\"}; no answer file",
    "X-2 = wake-waiter.ts:22-24: a non-zero exit other than agent_not_found is host_error, NEVER lost. Same root cause as A1-T2-1 (wake-waiter.ts:143); plugin_pane_not_found also gives lost. Controls: server_not_running gives host_error (exit 0). The misleading detail comes from rowGone's fixed text (wake-waiter.ts:298). A lost wake drops the wait, so a live delegate behind a transient herdr error is treated as dead. A patched copy (=== \"agent_not_found\") makes the repro exit 0.",
  ],
  [
    "A1-T2-3", "P2.1", "reading",
    "herdrFailureCode returns \"\" for every exit code <= 0 (wake-waiter.ts:131) where failure_code returns \"\" only for exit 0, so on exit -1 with herdr's agent_not_found envelope AILANG says gone=true (code agent_not_found) and TS says gone=false (code \"\").",
    PAIR("P2.1", "A1-T2-3"), wit("A1-T2-3"),
    "run1's negative-exit class holds 2,225 P2.1 disagreements; 594 of them come from this line (run 3, with it patched, leaves 1,631, all decoder cases at exit -1). Plus 157,835 P2.2-only (every negative exit: TS \"\" against AILANG herdr_cli_rejected / herdr_failed_silently / herdr_json_undecodable / a herdr code). Exit -1 with no spawnError is what the production runner returns for a signal-killed herdr (A1-T2-4), there with \"killed by SIG...\" appended to stderr. A patched copy with === 0 makes this repro exit 0.",
  ],
  [
    "A1-T2-4", "X-1", "reading",
    "herdrFailureCode gives the success code \"\" to a failed call: the real createHerdrRunner maps a herdr child killed by a signal to {code:-1, stderr:\"killed by SIGKILL\"} with no spawnError, and the r.code <= 0 test returns \"\".",
    `bun ${OUT}/repro/x1_signal_exit.ts`,
    "herdr child that dies by SIGKILL (stub: kill -KILL $$); runner result {\"code\":-1,\"stdout\":\"\",\"stderr\":\"killed by SIGKILL\"}",
    "X-1 = the function's doc comment (wake-waiter.ts:128): \"\" on success. Reachable in production: an OOM kill or external kill of a herdr child. The waiter still replies host_error (callers check r.code === 0 themselves), but its detail reads \"herdr agent get w1:p1 failed (exit -1, code ): killed by SIGKILL\" (describeHerdrFailure). Same line as A1-T2-3; a patched copy with === 0 makes the repro exit 0.",
  ],
  [
    "A1-T2-5", "P2.1", "execution",
    "means_agent_gone is true for herdr's agent_not_found envelope followed by more text (here \"\\nkilled by SIGTERM\"), because std/json decode accepts a JSON prefix and ignores the rest; JSON.parse in herdrFailureCode rejects the whole string, so TS says herdr_cli_rejected, gone=false.",
    PAIR("P2.1", "A1-T2-5"), wit("A1-T2-5"),
    "5,717 P2.1 + 109,027 P2.2-only in run1. Any trailing non-whitespace triggers it: a letter, }, ,, a second envelope, U+0000-U+0008, U+000E-U+001F, U+0085, U+180E, U+200B. Root cause is the AILANG v0.54.14 stdlib decoder, reached through json_error_field's decode (types.ail:1146). The witness's stderr is what wake-waiter's runner builds when herdr is killed after writing its error (wake-waiter.ts:514), though there with exit -1. Whether herdr ever writes anything after its envelope is not measured.",
  ],
  [
    "A1-T2-6", "P2.1", "reading",
    "failure_shape recognises herdr JSON only by the substring {\"error\" (types.ail:1140), so a valid agent_not_found envelope whose error key is not first, or is spaced, is plain_text -> herdr_cli_rejected -> gone=false in AILANG, while TS parses it -> agent_not_found -> gone=true.",
    PAIR("P2.1", "A1-T2-6"), wit("A1-T2-6"),
    "644 P2.1 in run1 for this class alone; most of the 1,277 in A1-T2-7's class are also spaced. Other triggering forms: { \"error\": ...}, {\"error\" :...}, pretty-printed, {\"\\u0065rror\":...}. herdr's measured output puts error first ({\"error\":...,\"id\":\"cli:agent:get\"}), so this is reachable only if herdr's serialisation changes.",
  ],
  [
    "A1-T2-7", "P2.1", "execution",
    "herdrFailureCode trims with String.prototype.trim, which strips Unicode spaces that JSON does not allow, so the agent_not_found envelope after a leading U+3000 is gone=true in TS, while AILANG's decode rejects it (herdr_json_undecodable, gone=false).",
    PAIR("P2.1", "A1-T2-7"), wit("A1-T2-7"),
    "Leading U+1680, U+2000-U+200A, U+2028, U+2029, U+202F, U+205F, U+3000 split the twins. Leading U+FEFF, U+00A0, U+000B, U+000C and U+0085 do not, and neither do trailing Unicode spaces. G4 tried every code point <= U+3000 matching \\s, plus U+0085, U+180E, U+200B and U+FEFF. 1,277 P2.1 in run1 for this class (mostly combined with A1-T2-6 spacing). Low reachability: herdr writes ASCII JSON.",
  ],
  [
    "A1-T2-8", "P2.1", "execution",
    "With a repeated key, TS (JSON.parse) keeps the last value and AILANG (std/json get) the first, so {\"error\":{\"code\":\"timeout\",\"code\":\"agent_not_found\",...}} is gone=true in TS and code timeout, gone=false in AILANG; the reverse order flips both.",
    PAIR("P2.1", "A1-T2-8"), wit("A1-T2-8"),
    "380 P2.1 + 5,750 P2.2-only in run1; duplicate error keys behave the same way. Reachability not shown: no measured herdr output repeats a key.",
  ],
  [
    "A1-T2-9", "P2.1", "reading",
    "failure_shape tests contains(stderr, \"nested herdr\") before the JSON test (types.ail:1139), so herdr's agent_not_found envelope whose message mentions \"nested herdr\" is nested_herdr, gone=false in AILANG, while TS reads its code: agent_not_found, gone=true.",
    PAIR("P2.1", "A1-T2-9"), wit("A1-T2-9"),
    "80 P2.1 in run1. It also contradicts means_agent_gone's own comment (agent_not_found = the agent is gone) within AILANG alone. An AILANG mutant with the two tests swapped makes this repro exit 0 (SUMMARY.md, controls). Reachable only if a herdr message echoes text containing \"nested herdr\". Extension-generated targets (mot-dlg-..., pane ids) do not.",
  ],
  [
    "A1-T2-10", "P2.1", "execution",
    "AILANG's decode rejects a number outside float64 range anywhere in the stderr JSON (here \"id\":1e309), so failure_code is herdr_json_undecodable, gone=false, while JSON.parse reads it as Infinity and TS returns agent_not_found, gone=true.",
    PAIR("P2.1", "A1-T2-10"), wit("A1-T2-10"),
    "23 P2.1 in run1 (1e309, 1e999, -1e999, in the error object or beside it). These agree: 1e308, 4.9e-324, 1e-400, 9007199254740993, a 30-digit integer, 64- and 600-deep arrays, every JSON escape including \\u0000 and surrogate pairs, raw U+2028 inside strings. Reachability: the measured envelope carries no numbers.",
  ],
  [
    "A1-T2-11", "P2.2", "execution",
    "A stderr that contains herdr's {\"error\" marker but is not valid JSON (a truncated agent_not_found envelope) is herdr_json_undecodable in AILANG and herdr_cli_rejected in TS (gone agrees: false).",
    PAIR("P2.2", "A1-T2-11"), wit("A1-T2-11"),
    "Largest P2.2-only class in run1: 159,690. At the K6 boundary: not herdr JSON, but it carries herdr's marker; whether the twins should agree here is K6's open question. A truncated envelope is what a herdr killed mid-write would leave.",
  ],
  [
    "A1-T2-12", "P2.2", "execution",
    "A stderr that is valid JSON but not herdr's error envelope ({\"id\":\"cli:agent:get\"}; also null, 1, \"text\", [], {}) is herdr_json_undecodable in TS (it parsed) and herdr_cli_rejected in AILANG (no {\"error\" substring); gone agrees.",
    PAIR("P2.2", "A1-T2-12"), wit("A1-T2-12"),
    "K6: outside herdr's JSON, so possibly intended. Counted in run1's ail-error-substring-gate(ts-parses) P2.2-only class (10,124), which also holds the P2.2 side of A1-T2-6 (spaced envelopes with other codes).",
  ],
  [
    "A1-T2-13", "P2.2", "reading",
    "Empty stderr on a non-zero exit other than 2 is herdr_failed_silently in AILANG and herdr_cli_rejected in TS.",
    PAIR("P2.2", "A1-T2-13"), wit("A1-T2-13"),
    "K6, known: TS has no herdr_failed_silently. Gone agrees. Listed for completeness; whether the twins should agree here is open.",
  ],
  [
    "A1-T2-14", "P2.2", "reading",
    "The measured #158 stderr \"error: nested herdr is disabled by default.\" (exit 1) is nested_herdr in AILANG (its own test vector, types.ail:1166) and herdr_cli_rejected in TS.",
    PAIR("P2.2", "A1-T2-14"), wit("A1-T2-14"),
    "K6, known: TS has no nested_herdr. Gone agrees. 17,500 P2.2-only in run1 (any non-JSON stderr containing \"nested herdr\"). Listed for completeness.",
  ],
];

const header = ["report_id", "property", "route", "claim", "repro", "witness", "notes"];
for (const r of rows) for (const f of r) if (/[\t\n\r]/.test(f)) throw new Error(`tab/newline in ${r[0]}: ${f}`);
fs.writeFileSync(path.join(OUT, "reports.tsv"), [header, ...rows].map((r) => r.join("\t")).join("\n") + "\n");
console.log(`wrote ${rows.length} reports`);
