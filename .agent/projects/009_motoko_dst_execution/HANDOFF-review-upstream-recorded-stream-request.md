# Handoff: review the upstream recorded-stream request before it is sent

Audience: a fresh agent session with no context from the drafting session. You are the last check
before an artifact leaves this repo and reaches an external project. Once it is filed, a wrong
claim is public and attributed.

## Mission

Review `.agent/projects/009_motoko_dst_execution/UPSTREAM-REQUEST-ailang-recorded-stream-api.md`
for readiness to send to `sunholo-data/ailang`. It asks for a recorded-stream API — one that keeps
`stepWithStream`'s live callback delivery *and* returns the exact ordered observed chunks — because
the deterministic-test-world ADR in this project needs both live streaming and an exact-chunk
trace, and the current API supports only one at a time.

**Two failure modes matter more than everything else, in order:**

1. **A false or unverifiable claim.** This is an outbound report; every quoted command output,
   error string, line number, version fact, and validation figure must be reproducible *now*, on
   this machine, exactly as written. The drafting session already shipped — and then caught — one
   false bug in an earlier revision (a phantom `Message`/`ImagePart` breakage that was an artifact
   of stdlib resolution). Assume another could survive. Re-run, do not re-read.
2. **The wrong ask.** A technically-true report that requests the wrong API wastes the one round of
   upstream attention we get. The remedy sketch is the only *proposal* in the document; the rest is
   evidence. Attack the sketch hardest.

## Inputs (read in this order)

1. The request itself (above).
2. `.claude/skills/ailang-feedback` — the channel/format contract this report must satisfy
   (version string, minimal standalone reproduction, expected-vs-actual, category routing).
3. `.agent/projects/009_motoko_dst_execution/spike/README.md` — the evidence base, **including its
   "Toolchain resolution caveat"**: `ailang check` on a file outside a project source root resolves
   a *different, newer* `std/ai` than the project's pinned stdlib. This caveat is the reason the
   earlier false bug happened; internalize it before you run anything.
4. `.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` — the
   blocked ADR, for whether the report's framing of "why this matters" matches what the ADR
   actually requires (returned complete trace, exact-program replay).
5. Source only as needed to verify a cited anchor (e.g. `src/core/ai_compat.ail:193` for the
   four-field `Message`).

## Review method (all four passes required)

### Pass 1 — Re-run every quoted result under project module resolution

This is the load-bearing pass. **The caveat from input 3 governs it: a loose `ailang check` is not
valid evidence.** Reproduce each of these under a real project module path (copy into
`scripts/dst/zz_*.ail` with a matching `module scripts/dst/zz_*` line, run, delete), and confirm
the document's text verbatim:

- Repro A (state-returning callback) — the exact error string **and line/column** shown.
- Repro B (`SharedMem` callback) — same.
- The positive control passes and prints the quoted three lines.
- The representation-test figures: `6/6` PASS lines and `live_projections=17 final_passes=1
  bad_markers=0`.
- The `parallel_passes=8 bad_markers=0` figure.

Any mismatch in error text, line number, or count is a finding. Confirm too that the snippets *as
printed in the document* produce the *line numbers printed in the document* — an earlier revision
quoted line numbers from the un-abridged originals, which did not match the abridged code shown.

### Pass 2 — Attack the remedy sketch

The draft's own reviewer-checklist item 1 already flags that the sketch
`Result[{result, chunks}, AIError]` **loses chunks on the error path**, while the spike explicitly
validated partial-stream-then-error. Confirm that this contradiction is real and still present in
the sketch (the checklist notes it, but the sketch itself has not been rewritten). Then pressure
the rest:

- Does the ask preserve *both* live callback delivery and capture, or could an implementer satisfy
  the letter by dropping the callback and returning a list at the end (silently killing streaming)?
- Is the additive-function framing (`stepWithStreamRecorded`) vs. changing `stepWithStream`'s
  return type stated clearly enough that upstream knows which we prefer and that we accept either?
- Is the identity guarantee stated (returned chunks == chunks as delivered, and
  `ContentDelta` concatenation still equals `message.content`)?

Report whether the sketch, as written, would produce the API we actually need. It currently would
not — verify and say so.

### Pass 3 — Version and toolchain honesty

The report reproduces on the pinned floor but hedges about v0.30.0 (latest). Check that every
version claim is stated as what it is:

- Is anything asserted about released v0.30.0 that was only read from docs, not compiled? The
  report should claim only docs-level evidence for 0.30.0 and say so.
- Is the "files outside a project root resolve a newer `std/ai`" observation stated as an
  observation, not a claim about the released compiler?
- `ailang --version` on this machine, and the `ailang.toml` floor — still what the Submission
  Fields block says?

### Pass 4 — Send-readiness against the skill

- Does the report contain everything `.claude/skills/ailang-feedback` requires of a good report
  (version verbatim, standalone reproduction, expected vs actual, category)?
- Is the recommended channel (Channel 1, GitHub issue for a tracked URL) still the right call given
  the report's length and the ADR's need to cite a URL?
- Are the five checklist judgment calls each genuinely a human decision, or has one been resolved
  by facts you can now settle (e.g. is `arniwesth/motoko_agent` public — which decides the
  link-the-spike question)?

## Output contract

Append a `## Review Comments` section to the request document itself. Do not rewrite the body
unless the user explicitly asks after review.

Number findings `R1..Rn`, most severe first. Each finding:

- The defect in one sentence.
- Grounding: the **exact command you ran** and its output, or a `file:line`.
- A concrete **Action:**.

Then:

- `What is accurate` — name the claims you re-ran and confirmed, so a later reader knows the
  evidence was checked, not assumed.
- `Send/hold recommendation` — one line: send as-is, send after N specific edits, or hold. The
  error-path gap in the remedy sketch is likely a send-blocker; say so if you agree.

State your model id and date at the top of the section.

## Constraints

- **Do not send the report.** No `gh`, no `ailang messages send`, no `submit_feedback`, no `curl`
  to the MCP endpoint. Review only. Filing is a separate, explicitly-authorized step.
- Verify by execution, not by reading the spike transcript or this handoff. A claim you did not
  re-run is a claim you cannot certify.
- Clean up scratch files you create under `scripts/dst/` (or use the scratchpad dir); do not leave
  `zz_*` files or modify the real spike probes, the Makefile, or CI.
- Do not re-litigate the *decision* to ask for a recorded-stream API — the spike settled that the
  IO-only-projection alternative moves the oracle off the driver. Attack the request's claims and
  the specific shape of the ask, not the premise.
- If nothing survives, say so plainly and still record the residual risk: the ask is only as good
  as upstream's willingness to add API surface, and the error-path shape is the part most likely to
  need a follow-up round.
