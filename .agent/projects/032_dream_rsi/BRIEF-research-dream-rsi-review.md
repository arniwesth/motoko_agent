# Brief: adversarial review of RESEARCH-dream-rsi-implications.md (v1)

Repo: /workspaces/motoko_agent, branch `arniwesth/013-plan003-and-herdr`, HEAD `2062605`.
Read-only review: edit no file under the repo except the one review document you write; run no
commit; run no `make dst` or any sweep. Other agents are active in this working tree (two motoko
workers in workspace w3, several idle claude sessions). Make no claim about uncommitted changes
other than the note under review and its directory; cite HEAD for everything else. You are
inside herdr (`HERDR_ENV=1`); do not open, close, focus or prompt any pane or agent.

## Under review

`.agent/projects/032_dream_rsi/RESEARCH-dream-rsi-implications.md` — v1, 2026-09-19, a research
note (no decisions; §7 lists undecided follow-ons). It reads a 2026 Google/DeepMind paper,
Dream-RSI, against Motoko's DST architecture and the RSI research direction. Give a verdict per
numbered TL;DR claim (§0 items 1–6) and per concrete candidate (§4.1–4.5): ACCEPT / ACCEPT WITH
CORRECTIONS / REJECT, with the reason, in the same table shape as
`.agent/projects/013_core_architecture_for_dst/REVIEW-adr001-v2-verdicts-codex.md` §1. Read that
file first: it is the standard this review is held to — every claim re-measured at HEAD, source
coordinates re-read, no verdict from prose alone.

## The paper (check the note against it, not the reverse)

- Site: https://dream-rsi.com/ . PDF: https://dream-rsi.com/assets/dream-rsi.pdf (36 pp.).
- A local copy of the PDF: `/home/motoko/.claude/projects/-workspaces-motoko-agent/e164d271-91fe-4e8b-933d-2ea008a5cf6c/tool-results/webfetch-1789739196389-e9om2l.pdf`
- A pypdf text extraction of it (2181 lines): `/tmp/claude-1001/-workspaces-motoko-agent/e164d271-91fe-4e8b-933d-2ea008a5cf6c/scratchpad/dream-rsi.txt`.
  `pypdf` is importable with `PYTHONPATH=/tmp/claude-1001/-workspaces-motoko-agent/e164d271-91fe-4e8b-933d-2ea008a5cf6c/scratchpad/pylib` if you want to re-extract. No
  `pdftotext`/poppler is installed.
- The code repository is unreleased; the note's mechanism claims come from the paper body §3
  and the policy-development prompt in Appendix B. Treat the extraction as the source of truth
  for quotes; if a quote in the note is not in the extraction, say so.

## Motoko inputs the note relies on (read them; check the note against them)

- `design_docs/planned/m-motoko-dst-recursive-self-improvement.md` — the direction doc.
- `.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`
  — D2 (~:688), D3 (~:802), D9 (~:2323), D11 (~:2348).
- `.agent/projects/013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md` — v5,
  TL;DR at ~:424, D1–D8 from ~:530. The note's TL;DR claim 2 and §3.1 rest on this file.
- `.agent/projects/013_core_architecture_for_dst/HANDOFF-2026-09-17-plan004-post-p1g-p22-blocked.md`
  — the PLAN-004 state the note's §6 item 4 cites.
- Module headers: `src/core/dst_replay.ail`, `src/core/dst_discovery.ail`,
  `src/core/dst_generator.ail`, `src/core/dst_corpus.ail`, `src/core/dst_invariants.ail`,
  `src/core/dst_execution.ail`, `src/core/dst_result.ail`.
- `papers/motoko-dst-report/SCOPE.md` and `DRAFT.md` §6, §8 — the vacuity accounting.
- `.agent/projects/030_harness_playbook/RESEARCH-harness-playbook-implications.md` — the shape
  the note follows; not under review.

## Questions the review must answer, beyond the verdict table

1. **ADR-004 is "already Dream-RSI-shaped"** (TL;DR 2; §3.1 table and its three differences).
   Check every row of the §3.1 table against ADR-004 v5's actual D1–D8 text. List each row that
   overstates, misstates, or maps to a decision that says something else.
2. **Does the paper say what the note attributes to it?** Check every quoted phrase in §0–§3
   against the extraction; check eq. (1), the selection rule and the "never worse" derivation,
   the Appendix B rules the note lists in §1.3, the Fig. 6 attempt counts in §1.4, and every
   number in the §1.4 table. List every misquote, misattribution, or number that does not match.
3. **"Refusal versus silence"** (TL;DR 2; §3.1 difference 1). Is "silent" a fair reading of
   `Child(v;T)` possibly empty plus "cannot earn replay reward", or an overreach? Is the Motoko
   side accurate — D2's HarnessFailure list and ADR-004 D3's verdict set?
4. **§3.2** claims regression replay "cannot restrict a changed harness's action space" and so
   fails closed. Read D2's regression-replay clause. Is there a mechanism the note missed?
5. **§3.3** claims Dream-RSI's tree recorder has "the identical exposure and no check". Is there
   anything in the paper — prefix-safe facts, `live_cycle_manifest.json` sidecars, the beta
   sweep, anything in §3 or the appendices — that functions as a recorder check the note
   overlooked?
6. **§4.1** (offline scheduler over corpus history): buildable from what D11 and
   `src/core/dst_corpus.ail` record today? Name the fields that exist and the ones that do not.
7. **§4.2** (inside-the-program / outside-the-program split): is this already present in
   ADR-004's admissible class (D3, "validity envelope"), in whole or in part? If so, say what
   the candidate collapses to.
8. Is there a cheaper or stronger candidate the note did not consider? ≤ 10 lines.
9. Everything the note gets factually wrong about the code, the ADRs, the handoff, or the paper:
   list every one, with the coordinate that refutes it.

## Output

Write `.agent/projects/032_dream_rsi/REVIEW-research-dream-rsi-v1-verdicts-codex.md` in the shape
of `REVIEW-adr001-v2-verdicts-codex.md`: header (date, HEAD, reviewer, model, method, what you did
not do), §1 verdict table (one row per TL;DR claim 1–6 and one per candidate §4.1–4.5), then one
section per TL;DR claim, then the nine questions, then "Corrections to the note" as a numbered
list. Every claim carries a file:line or a command and its output. Temporary evidence goes in a
directory you create outside the repo. When finished, reply with only the review file's path.
