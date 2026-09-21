# Review round 3 — 2026-09-20 (DRAFT-3.md)

Target: [DRAFT-3.md](DRAFT-3.md) and its [PDF reading copy](DRAFT-3.pdf), with
[SCOPE-3.md](SCOPE-3.md) and [REVIEW-round1.md](REVIEW-round1.md) as context.

Protocol: one reviewer (Claude Fable 5.1, in a session with repository access), not
the three-persona protocol of round 1. Method: read the draft in full; fact-checked
every testable current-code claim against the checkout at `7e5ec5f9` (HEAD, with no
modified tracked source files); reran the two checker selftests the draft cites;
checked every link target and external URL; rendered and inspected the PDF. No DST
sweep, corpus admission, or mutation study was run. The score below is one reviewer's
and is not comparable to round 1's three-reviewer median.

Calibration as in round 1: 6.0 workshop · 7.0 main-conference · 8.0 strong accept.

## Score

| Reviewer | Lens | Score | Recommendation |
|---|---|---|---|
| R | DST practitioner with repo fact-check, plus a print-copy pass | 6.5 | Weak accept; revise before publication |

Every current-code claim I tested is correct, the structure works for an external
reader, and the running example is sustained through §6. The score is held below 7
because the report executes nothing beyond two checker selftests, and round 1's two
major unresolved items (bug yield, oracle-strength study) remain future work.

## Verification record

All checks were made at `7e5ec5f9daf7d19076c2792e91701a896fc79126` on 2026-09-20.
`git status --short` shows no modified tracked files under `src/`, `scripts/`, or
`tools/`; the only untracked source-adjacent files are
`scripts/dst/mem_canonical_bench.ail`, `scripts/dst/mem_growth_probe.ail`, and
`src/eval/journal/testdata/MATRIX.tsv`, none of which the draft cites.

| Draft claim | Where checked | Result |
|---|---|---|
| Snapshot hash (§8.4, README, SCOPE-3) | `git rev-parse HEAD` | Matches |
| 53 relative link targets | filesystem | All exist |
| 3 external URLs (FoundationDB paper, TigerBeetle architecture, Antithesis DST page) | HTTP | All return 200; Zhou et al., SIGMOD 2021 is the correct attribution |
| §2.2 capability "atoms" by kind and index | `src/core/dst_profile_coverage.ail:83–101` | Matches |
| §3.4 six accounted classes; approval reads under tool execution; extension forwarding exempt | `src/core/world_ordinal.ail:47–54`; `tools/driver_leaf_inventory/derive.py` header (ten `ExtPorts` forwarding closures exempt) | Matches |
| §3.4 wire checker rejects requests outside a frame, missing END, pending witnesses, empty evidence | `scripts/dst/run_world_framed_wire.sh:84–106`, selftest classes | Matches |
| §3.5 `Bounded` / `Disabled` / `Unknown` with retained misses | `src/core/context_limit.ail:43–45` | Matches |
| §4.2 eleven required fault ids = 5 provider + 3 tool + 2 approval + 1 extension; some conditional | `src/core/dst_fault_catalogue.ail:254–271`, conditional rows `:405–420` | Matches |
| §4.3 discovery witnesses: provider calls, tool dispatches, approvals, clock delta, expected env reads | `src/core/dst_discovery.ail:260–310` | Matches |
| §4.4 replay reference carries path and identity; RNG canary | `src/core/dst_run_report.ail:369–374`; `scripts/dst/compaction_seeded_dst.ail:98` | Matches |
| §5.1 wait descriptors (delegate, operator, timer); step budget is `StepBudgetExhausted`, not `Park`; waiter orders by wait list and cancels losers | `src/core/phase_vocab.ail:442–445`; `src/core/step_machine.ail:103–111, 145–147`; `src/tui/src/wake-waiter.ts:24–25, 181` | Matches |
| §5.2 torn-final-line rule scoped to the tail; trailing unpaired call stripped and reported; park/wake entries | `src/core/journal.ail:3444–3450, 3119, 1179–1180` | Matches |
| §5.3 AILANG twin of the host writer feeds `JournalFold` | `src/core/dst_invariants.ail:1131, 1987` | Matches |
| §6.2 `PortedWorld(Ports, WorldState)`; guarded seams | `src/core/test/stub_step.ail:69`; `src/eval/journal/seams.ail` | Matches |
| §6.3 `NoReplay` for admission, `StrictAgainst(program.interactions)` for candidates | `src/core/dst_invariants.ail:600–601`; `src/eval/journal/bridge.ail:61`; `candidate_checks_run.ail:108` | Matches |
| §6.4 T0 excludes extensions, streaming, cross-turn lifetime, real tools; refuses continuation starts; cuts at retries and parks; allocation is the primary measure; corpus entry composition | ADR-004 D1, D4, D6, D7 and the cutoff table | Matches, with one omission noted as finding 9 |
| §7.2 profile versions 32 / 21 / 13 / 2; four no-ops extensions; herdr two substantive entries with `exit_intent[0]` excluded | `dst_driver_only.ail:512`; `dst_driver_plus_no_ops.ail:215, 424–425`; `dst_driver_plus_compose.ail:220`; `dst_driver_plus_herdr.ail:123, 193, 453–466` | Matches |
| §7.3 `FamilyEvidence`; evaluator census with unobserved categories; historical one-of-forty | `dst_invariants.ail:2043`; `src/eval/journal/witness.ail:197–204`; round-1 arithmetic check | Matches |
| §7.5 thirteen families, in the draft's order | `dst_invariants.ail:228–247`, length asserted `:2190` | Matches |
| §8.1 `dst_l2` runs the harness-boundary test file | `Makefile:2791–2792` → `src/tui/src/harness-dst.test.ts` | Matches |
| §8.2 timed corpus phase separate; known-red list; `dst_target_list`; CI 5 seeds from base 1, 500 date-derived on schedule; separate `dst_l2` job | `Makefile:632, 697, 725`; `.github/workflows/verify-extensions.yml:165–172, 243–261` | Matches; see finding 2 |
| §8.3 wire-checker selftest passes; inventory selftest 0 failures, 26 clean/returned leaves, 6 clean receipts | Rerun 2026-09-20 | Reproduced exactly |
| §8.4 `RealEntry` admission arm calls `jr_real_refused`; candidate mode refuses real entries; real-entry work is outside this checkout | `scripts/eval/journal_replay.ail:238, 60–61`; `STATE-p23-round4.md` places P2.3 in `/workspaces/motoko_agent-eval` | Matches |
| §8.4 generic profile runner and commands/interpreter rewrite not delivered | 013 ADR-001 D4, §2.C rows | Matches |
| §9.1 physical-fault reopen triggers name crash recovery and resume-from-ledger | `dst_fault_catalogue.ail:437–438` | Matches |
| Round-1 regression list | grep | No "prints and guards"; no sole-emitter phrasing; novelty claims removed outright, so #12 is moot |

PDF: 19 pages. Both Mermaid figures render. See findings 3 and 4 for how they and the
citations read in print.

## Findings and disposition

| # | Severity | Finding | Suggested fix | Disposition |
|---|---|---|---|---|
| 1 | MAJOR | No executed results. The only run evidence is two checker selftests. The abstract opens with "Motoko tests these responsibilities by running its production session driver" and the report never reports a run. Round 1's #4 (bug yield) and #5 (mutation study) are still future work in §9.2. | Either run `make dst` at the pinned revision and report the per-target summary with refusals and the known-red outcome (SCOPE-3 step 2), or reframe title and abstract as an architecture-and-methodology report. | OPEN |
| 2 | MAJOR | Known-red membership undisclosed. §8.2 says a named known-red list exists and does not launder failures, but not that at this snapshot it contains `driver_plus_herdr` and `herdr_graded`. Table 4 presents `driver_plus_herdr` v2 as a declared profile with substantive evidence, so a reader infers its gate is green. The Makefile comment at `:686–697` says the run clauses regressed at PLAN-002 W4 for lack of a seeded wake, bisected to `d72fff1`, disposition pending. | One sentence in §8.2 naming the two entries and the cause, and a note on Table 4 or Table 7. | OPEN |
| 3 | MAJOR (PDF) | Citations unusable in the reading copy. Reference-style links become bare trailing fragments in print ("Port definitions.", "Execution bridge; invariant evaluator.", "Framed-wire checker."), and Appendix A's table shows link text with no path. The README calls the PDF the reading copy, so the reader has no way to follow a source. | In the PDF build, print paths: a path column in Appendix A, or footnotes carrying the repo path for each in-text citation. | OPEN |
| 4 | MODERATE (PDF) | Figures render white-on-black. Figure 1 on page 4 and Figure 2 on page 10 use the dark Mermaid theme on a white print page; Figure 2 fills most of its page. Page 19 carries one reference and one sentence. | Neutral or light Mermaid theme in the build; tighten Figure 2's layout; pull the last reference onto page 18. | OPEN |
| 5 | MODERATE | Hedge density. About 54 negated-claim sentences in 7,610 words, roughly one per paragraph, many as a closing "it does not claim". The cooperative-trust caveat appears in §3.3 and §6.4; "not a fresh verdict" appears under Table 3, under Table 4, and in §8.3. SCOPE-3's own rule keeps a qualification only where dropping it changes a claim. | Let §6.4, §8.3, §8.4, and §9.1 carry scope. Cut duplicates in the body; keep a qualification only where its removal would change what the sentence asserts. | OPEN |
| 6 | MINOR | §2.3 "Capabilities are process-wide in this design" has no citation and no repo text states it. The poison probe (`scripts/dst/world_state_poison.ail` header) and the compose registration disclosure are consistent with it. | Cite one of those, or the AILANG runtime documentation on capability grants. | OPEN |
| 7 | MINOR | §8.3 "During preparation" refers to Draft 2's preparation per SCOPE-current. The results reproduce today at the same HEAD. | Name the draft or refresh the date; optionally cite this rerun. | OPEN |
| 8 | MINOR | Numeral style: "26 clean/returned leaves and six clean receipts" in one sentence, while "eleven", "thirteen", "forty" are spelled out elsewhere. Table 4's separator row has irregular widths (cosmetic; no PDF effect). | Pick one convention. | OPEN |
| 9 | MINOR | §6.3 lists the corpus entry's parts but omits the exposure log that ADR-004 D6 includes. It is what makes the privacy scan reviewable, which §6.4's trust discussion relies on. | Add it to the list. | OPEN |
| 10 | MINOR (process) | DRAFT-3.md, DRAFT-3.pdf, README.md, SCOPE-3.md, and this review are untracked. The report pins the source revision but not its own. | Commit before circulating. | OPEN |

## Carried from round 1

| Round-1 # | Item | Status in Draft 3 |
|---|---|---|
| 4 | Bug-yield evaluation | UNRESOLVED; §9.2 names a cumulative bug ledger as future work |
| 5 | Oracle-strength mutation study | UNRESOLVED; §7.5 names the existing negative controls and defers the study to §9.2 |
| 9 | Replay normalization rules | Addressed in principle by §4.4 ("equality is defined over the recorded representation"); the rules themselves are still not enumerated |
| 14 | Abstract density | Partially addressed; the abstract is one 151-word paragraph carrying about ten distinct concepts |

## Regression-check list for the next round

1. Known-red membership stated wherever `driver_plus_herdr` is presented as evidence (#2), or the entries have been dropped from `DST_KNOWN_RED` with a passing summary.
2. PDF shows repo paths for in-text citations and Appendix A (#3); figures use a light theme (#4).
3. Either a results section derived from a sweep at the pinned revision, or a title and abstract that no longer imply one (#1).
4. Round-1 #2 and #12 stay clean: no "prints and guards"; no unhedged novelty claim.
5. If P2.3 lands before publication, Table 7's journal-evaluation row and SCOPE-3 no longer say the `RealEntry` arm calls `jr_real_refused`, and the snapshot hash is re-pinned.
