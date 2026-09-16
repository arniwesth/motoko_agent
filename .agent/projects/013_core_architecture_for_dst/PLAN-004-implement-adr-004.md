# PLAN-004: implement ADR-004 — a session journal as an evaluation source

Date: 2026-09-15 (v1–v1.2), 2026-09-16 (v2). Status: **proposed v2 — re-grounded on ADR-004 v5, which the
operator accepted at `V5G`; awaiting `PREV` → `PLAN2G`.** Review history: v1 → `REVIEW-plan004-v1-verdicts-codex.md`,
**RETURN** (eight changes; the early split accepted as provisional work); v1.1 →
`REVIEW-plan004-v1.1-delta-verdicts-codex.md`, **RETURN** (five changes); v1.2 → `REV2·a2`,
`REVIEW-plan004-v1.2-delta-verdicts-codex.md`, **ACCEPT WITH CORRECTIONS** (six corrections, applied, §9), on
which the operator settled **`PLAN1G`** (2026-09-15T20:00:11Z). All three rounds Codex `gpt-5.6-sol` at HEAD
`3920814`. v2 is `PSYNC`'s document: every v5 marker of v1.2 replaced by v5's decision, P1–P3 re-checked
against v5 at HEAD, the changed parts under new ids in a new operator graph (§9). `PREV` reviews it; the
operator settles `PLAN2G`.

Governing decision: `ADR-004-journal-as-evaluation-source.md` **v5, Accepted**. v4 was returned
(`REVIEW-adr004-v4-verdicts-codex.md`: D1, D3, D5 RETURN; the rest ACCEPT WITH CORRECTIONS; O7 retained); v5
folded its nine required changes (`21c1728`) and was reviewed by `V5R·a1` — **claude (Claude Fable 5.1), not
Codex**, which was unavailable in this container, stated in the file's name —
`REVIEW-adr004-v5-verdicts-claude.md` (sha256 `b53604f8…`): **ACCEPT WITH CORRECTIONS**, six textual
corrections C1–C6 plus one cosmetic, no v6, "PLAN-004 v2 may be written against v5". They are applied in
`988a863`. The operator settled **`V5G`** (2026-09-16T06:30:00Z): corrections accepted as applied; the D8/M15
ruling recorded (`AdmissionCheck` near-misses satisfy the per-check requirement; inapplicable rows stand as
reasoned); ADR-004 v5's status flipped to Accepted in this plan's commit.

**Where v1.2 stood and where v2 starts.** v1.2 split the work into provisional parts that needed no v5 answer
and everything else, which waited for `V5G` → `PSYNC` → `PREV` → `PLAN2G`. That split is now history:
`QRET`, `PLAN1G`, `V5`, `V5R`, `V5G` and `P2.1` are done (their settlements are in `run-plan004.json`, the
v1.2 graph, which stays the record through `PLAN2G`); `SWEEP` was in progress in that session when v2 was
written; `PRESERVE` and `SCAN0` remain ready. The running session ends at `PLAN2G` with a handoff, and a
**fresh** session starts on the v2 graph (§8); `SWEEP`, `P1.1` and P0 do not wait for `PLAN2G`, every other
P1 part does.

Grounded at: HEAD **`3920814`** for code on `arniwesth/013-plan003-and-herdr`. v2 was written at
`988a863`; `git diff 3920814 988a863 --stat -- src/ scripts/dst/ Makefile tools/` is **empty** (HEAD adds
ADR-004 v5, the review documents and P2.1's `scripts/eval/mem_guard.py` + `test_mem_guard.py`), so every
code coordinate below holds at HEAD. ADR-004 v5 is itself re-pinned to `3920814`; §0.9 keeps the
`d5edebf` → `3920814` drift table for readers of the v4 review. Operator plan graph:
**`.dagr/run-plan004-v2.json`** (run id `run-plan004-v02`; the v1.2 file `run-plan004.json`, run
`run-plan004-v01`, holds the settled history through `PLAN2G`). `dagr check --strict` clean proves the
document is well-formed — not that a review accepted anything; §0.10's transaction and the gates'
dependencies do that.

**Thesis.** A recorded live session becomes a world; one admission run of the parent over that world,
through the production traced entry and the harness's recording adapters, records an
`ExecutionProgram`; every candidate is then an ordinary strict replay of that program, graded by the
harness's own comparison, reconstitution, witnesses and invariant families, with source checks against
the journal and host log, a guard, and a verdict that names its envelope, all owned by an evaluator
pinned at a commit the candidate does not own.

**The numbers this plan is judged on** (ADR-004 TL;DR): a candidate in the admissible class is measured
on a real session's workload, deterministically, with a verdict naming what was and was not checked; a
candidate outside the class is refused before it runs; a diverged replay is not scored. Concretely at
`P3G`: `make journal_replay_budget` passes the parent on an admitted finite dev entry, **and rejects a
reviewed regression control by its allocation budget while K1–K7 pass** — never by a K0 or other
refusal.

---

## 0. Preconditions and standing rules

1. **The sweep.** ADR-001 D6: `make dst DST_JOBS=1` before any boundary edit; P1.1 is one, so `SWEEP`
   runs first. `Makefile:697` (`DST_KNOWN_RED := driver_plus_herdr herdr_graded`) is a **register**, not
   evidence of this sweep's reds. `SWEEP` records every target's result — including listed targets that
   pass — with exit code and closing summary. A red not explained by the register **blocks P1.1 until the
   operator rules** (directive).
2. **Memory.** cgroup limit 24 GiB; the 12 GiB `memory.current` rule
   (`HANDOFF-2026-09-13-plan001-p2d-sweep-pending.md`). Heavy runs: `SWEEP`, `P2.2`, `P3.1`, `P3.2`,
   `P3.3`, `P5`, and any delegate running `make dst`. **At most one at a time.** Until P2.1 lands no
   real-segment replay runs at all; after it, every real-segment run goes through the guard, whose `flock`
   is the enforceable exclusivity rule. The guard samples; it does not prevent an instantaneous cgroup OOM,
   so a trip, a missing `guard.json` or a monitor gap **invalidates** the run.
3. **Anchors.** P1.1 is line-neutral: `make anchors` and `make driver_leaf_inventory` green with no
   re-baseline. At `3920814` the pins are `stub_step.ail:203` (`anchors.sh:593`), `session.ail` 1471,
   1730, 1842, 4302, 4523 and `tool_phase.ail:484` (`anchors.sh:614–617`); the bridge span is
   `session.ail` 1085–1474 (`derive.py:154`). A P1.1 that cannot stay neutral **stops and reports**.
   Evaluator code lives outside `src/core` (item 5), so no other part moves an anchor.
4. **Vocabulary and schema.** No part adds a `LedgerEvent` variant, a `Ports` field, a program schema
   version (`execution-program/4` stays) or a recorder projection change (ADR-004 D2, Consequences).
5. **Where the evaluator lives** (a plan default; overridable in review): modules `src/eval/journal/`;
   runner `scripts/eval/journal_replay.ail` plus its shell driver `scripts/eval/journal_replay.sh`
   (identity collection, P1.6); protected-source checker `tools/eval_protected/`; guard
   `scripts/eval/mem_guard.py`; synthetic fixtures and their independent generator
   `src/eval/journal/testdata/`. None exists at `3920814`; at HEAD the guard and its test exist (P2.1, `55f1100`). Together they are "every evaluator path" for
   D3's refusal and D5's assembly. **E** is the commit `P1G` pins; from `P1G` on the evaluator is checked
   out at E in `../motoko_agent-eval` — `P1G` first checks that path does not exist (or is an existing
   worktree of this repo with no changes) and never overwrites it.
6. **Privacy and exposure** (D6), binding on briefs:
   - Corpus content — journal snapshots, excerpts, programs, tool outputs, seed messages — never enters a
     commit, a brief, a delegate prompt, a dagr note or a §6 record. Counts, digests, site indices,
     identities only.
   - **No real content is copied anywhere before `QRET` is answered** (item 11).
   - Every agent that reads or runs against real session content is recorded: before an entry exists in
     `.motoko/eval-corpus/_scan0/exposure.jsonl` (or the archive's `exposure.jsonl`), and those rows are
     **migrated** into each entry's exposure log when the entry is created. Warm-ups and profiling runs
     are rows too.
   - Held-out entries (P4) are never named, and their results never shown, **to any candidate-producing
     agent**. Motoko orchestrates candidate work and counts as one; P4 is the operator's.
7. **Commits.** A code part is **one commit**, written by the delegate as its last act, named
   `ADR-004 Dn: …`. Stated exceptions:
   - **no commit, a §6 record:** `SWEEP`, `SCAN0`, `P2.2`, `P3.1`, `P5`;
   - **review documents, not committed by the reviewer:** `REV1`, `REV2`, `V5R`, `P1.1R`, `PREV`, `P1R`;
     the orchestrator commits them with the next plan or ADR commit;
   - **operator decisions, no commit:** `QRET`, `PLAN1G`, `V5G`, `PLAN2G`, `P1G`, `P3G`, as directive
     events; `P1.1G` is checked by the orchestrator;
   - **documents:** `PLANW` (this plan's revisions through v1.2, first committed by `PSYNC` with v2);
     `V5` made **three** commits (§2: v4 + reviews, v5, the corrections); `PSYNC` one; `P4` whatever the operator's process
     produces, outside the repo.
   - §6 records carry HEAD, the command, its exit code and output excerpt, and what could not run.
8. **Tests.** Evaluator: `ailang check`, `ailang test src/eval/journal/<module>.ail`,
   `make eval_protected_selftest`, `python3 -m pytest scripts/eval/test_mem_guard.py`, and
   **`make eval_matrix`**, which runs the suites and writes `src/eval/journal/testdata/MATRIX.tsv` (§3).
   Harness regressions: `make strict_replay`, `make ledger_parity`, `make anchors`,
   `make driver_leaf_inventory`, `make event_vocabulary`. Make targets named here that do not exist are
   created by the part that introduces them. **Red first**, where it means something: when a test can be
   run before the implementation, the delegate records that failing run (command, exit, first failure)
   in the commit message; when it cannot, a **mutation check** (break the implementation once, show the
   named test fails, restore). An asserted ordering with no recorded failure is not credited.
9. **Coordinates.** ADR-004 v5 and this plan are both pinned at `3920814`, and the code paths are
   unchanged at HEAD `988a863` (header). The table records what moved between `d5edebf` (v4's pin) and
   `3920814` (ten commits, all PLAN-003 P4), for readers of the v4 review and its evidence; every brief
   still tells the delegate to resolve a stale reference by reading the code and noting the drift. Two rows
   are corrected in v2 per the v5 review (§4.2: `tool_outcome_record` is `:2133`; header correction C4).

   | v4 cited (`d5edebf`) | `3920814` = HEAD |
   |---|---|
   | `stub_step.ail` 901 lines; `recording_ports :621`; `recording_model_step :464` | 915 lines; `:635` (exported); `:478` (private). The sum at `:69` is unchanged |
   | `ports.ail` `world_tool :1677`; `recording_tool :2010` | `:1723`; `:2056` (+46 for these two). **Not a universal offset:** `record_interaction :1827`; provider outcome encoder `:2507`; `encode_exhausted_provider_outcome :2522`; `encode_tool_outcome :2577`; `tool_outcome_record :2133` (private; v1.2 said `:2126`, corrected per the v5 review §4.2) |
   | `session.ail` 6004 lines | 6320; unchanged: import `:195`; `ported_provider` **starts `:1532`**, its `GeneratedWorld` arm `:1545`; `provider_api_model :272`; `c2_suspend :2760`; `classify_candidate :3255`; `run_v2_session_traced :4423` |
   | `ledger_parity_dst.ail` 642 lines; import `:73`; `frame_ordinal0 :428`; `Ported` arm `:435` | unchanged |
   | D1's `ParkOrWake`: "no decoder at HEAD: `all_entry_types` is still ten types" | **Stale, withdrawn in v5**: `686da16` added `park` and `wake` (`journal.ail:1179–1180`, `:1253–1256`, twelve types). v5 D1: `Parked` is a **cutoff** (before the call-free stop-class call k preceding the park, `EndSuspended(k−1)`, C1); a wake-opened run is `Refused(ContinuationStart)`; a stray `wake` is the fold's refusal at `request_id` (`:1603–1614`), `MalformedEntry` here |
   | `derive.py` | +10 lines inside `TREE_MUTANTS` (`:645–654` by `git diff -U0`; the ADR header's C4 says `:642–654`, the same hunk); `BRIDGE_SPAN :154` unchanged; `:63–86`, `:320–329` unchanged |
   | `git check-ignore .motoko/eval-corpus/example` exits 1 | still exits 1 at `988a863` (P2.1 did not add the rule; it is `PRESERVE`'s) |

10. **Reviews: an append-only RETURN transaction.** Tested on synthetic documents (§6) and reproduced
    independently by the v1.2 review (`REVIEW-plan004-v1.2-delta-verdicts-codex.md` §2: ten stages, every one
    `dagr check --strict` → `[]`, prior attempts and event prefixes byte-identical). Two kinds of review:

    **(a) Artifact reviews** — `REV2` on `PLANW`, `V5R` on `V5`, `PREV` on `PSYNC`, `P1.1R` on `P1.1`. The artifact
    has an **author task**, which carries the round `policy`; the review task carries none. The **gate depends on
    both** (`PLAN1G` ← `PLANW`,`REV2`; `V5G` ← `V5`,`V5R`; `PLAN2G` ← `PSYNC`,`PREV`; `P1.1G` ← `P1.1`,`P1.1R`).
    The author is `done` only after an accepting verdict, so a `done` review never makes a gate ready by itself.
    1. **Author finishes.** The author task goes to `review`; its attempt is **not settled** — `working` with the
       author's locator while that pane lives, `queued` otherwise — so nothing is marked `done` and later
       rewritten.
    2. **The orchestrator opens the review by hand.** A queued review row renders `waits <author>` while the author
       is in `review` (its dep is not `done`); that is intended, and a session that only follows the ready queue
       would stall here. The review attempt opens with `cause: initial`, or `followup` ref the author attempt under
       review from round 2.
    3. **Verdict.** The review attempt settles `done` — the review's work succeeded — with a receipt holding the
       document path, its SHA-256 and the verdict word. In the **same** candidate document:
       - **ACCEPT**, or **ACCEPT WITH CORRECTIONS** whose corrections are applied: the author attempt settles `done`,
         its receipt naming the review attempt, the document's SHA-256 and each applied correction.
       - **RETURN:** the author attempt settles `rejected`, and a new author attempt opens with `cause: sent_back,
         ref: <review attempt>`. The author policy's consumed fail future `·aN` is **removed** and `·aN+1`
         forecast; keeping it collides (`E164`).
    4. **Rounds.** `rounds_max: 3`. After a **third** RETURN no fourth attempt opens: the author task goes to
       `blocked` with `unblock: "operator directive: continue, re-scope or stop"`, its loop future removed and only
       `<gate>·ask` kept. **dagr does not enforce this** — a fourth attempt with no directive is strict-valid (v1.2
       review §2, `06_unapproved_a4.json`) — so it is a writer rule: a fourth attempt is appended **only** in the
       same checked mutation that (i) appends the operator's `directive` event (`verb: unblock`) whose `detail`
       states how many further rounds are authorised, (ii) removes the answered `<gate>·ask` future, (iii) sets
       `policy.rounds_max` to the authorised total and forecasts a next round only if one remains, and (iv) cites
       the directive's `at` in the new attempt's `cause.reason`. The gate's receipt names that directive. A task
       that settles `done` ends its loop; a later reopening (`cause: gate_failed`) starts a new count, stated in its
       cause.
    5. **No bypass.** A directive may rule the corrections of an ACCEPT WITH CORRECTIONS verdict or authorise a
       further round; it never turns a RETURN into an acceptance.

    **(b) The aggregate review `P1R`.** P1's parts are depended on by later parts (`P1.5` on `P1.3`, `P1.9b` on
    `P1.7a`/`P1.7b`, `P1R` on `P1.9b`), so they cannot stay open waiting for one review at the end. Each P1 part
    **settles `done` on its own implementation receipt** (commit, gate commands, red-first or mutation record), as an
    ordinary task; `P1R` reviews the completed tree. On a `P1R` **RETURN**: `P1R`'s attempt settles `done` with the
    verdict; each **implicated** part keeps its prior `done` attempt **unchanged** — it was legitimately settled and is
    not rewritten to `rejected` — and gets a new attempt `cause: sent_back, ref: <P1R attempt>`; when every implicated
    part is `done` again, `P1R` gets a `followup` attempt. `P1G` requires every part's **latest** attempt `done` and
    `P1R`'s **latest** verdict accepting. No policy is declared (the implicated parts are not known in advance); a
    fourth `P1R` round needs (a)4's directive mutation. Tested by the v1.2 review:
    `09_aggregate_return_preserve_done.json`, strict `[]`, gate `waits`.
11. **Retention — ruled.** D6 fixes retention in PLAN-004. `QRET` asked the operator; the ruling
    (`QRET·a1`, directive `verb: answer`, 2026-09-15T20:00:11Z, copied into §6) **adopts this default**:
    every corpus item — `_archive/`, `_scan0/`, each `<entry>/` and its `runs/` — is kept until 90 days
    after `P3G`, or until ADR-004 is superseded, whichever is first. On supersession, the operator chooses
    per entry: delete, or migrate under the successor's reviewed rules (re-admission, D5); the default is
    delete. Deletion removes every copy (corpus paths, any scratchpad or `/tmp` evidence directory with real
    content, backups), is recorded in §6 with the paths and a `find` showing them gone, and leaves tracked
    records (counts, digests, identities). No real content was copied before the ruling; `PRESERVE`
    depends on `QRET` and is now ready.

---

## 1. Phases (ADR-004 D8 order)

| project | D8 | scope | effort (one review round each) |
|---|---|---|---|
| P0 | step 1 | retention ruling; preserve; sweep; heuristic pre-scan | 1½ delegate-days (≈1 elapsed with overlap; sweep wall time uncertain) |
| PLAN | — | `PLANW` rounds v1, v1.1 (both returned), v1.2; `REV1`, `REV2`; `PLAN1G` | done (settled 2026-09-15) |
| ADR | — | V5, V5R, V5G (done); PSYNC (this document: v2 plan + new graph file), PREV, PLAN2G | 4–6 (1–2 remaining) |
| P1 | step 2 | variant + review + gate; at E: reader (3 parts), digests, protected checker, world and seams, admission, source checks, witness and invariants, scan and entry, candidate runner (2 parts), P1 review, `P1G` | 18½–22 |
| P2 | step 3 | guard; calibration after `P1G` | 2½–3 |
| P3 | step 4 | admit the dev entry; the control; the budget target; `P3G` | 3–4 |
| AFTER | steps 5–7 | P4 held-out process (operator); P5 long admission; P6 T1 **canceled from this run** | P4 1, P5 1–3 |

**To `P3G`: 30–37½ delegate-days** (P0 1½ + PLAN ½–1 + ADR 4–6 + P1 18½–22 + P2 2½–3 + P3 3–4), **38½** if P3.2's calibrated escalation runs, one
review round per review; each extra round adds its review and its fix.

**The dependency skeleton** (the graph is authoritative; every gate also depends on its author task). An arrow from an author to its review — `PLANW ─ REV2`, `V5 ─ V5R`, `PSYNC ─ PREV`, `P1.1 ─ P1.1R` — is the **submission** order the orchestrator follows by hand (§0.10 (a)2), not always a graph dep: `REV2` has none, and the others' dep renders `waits` while the author is in `review`:

```
PLANW ─┬─ REV2 ─┬─ PLAN1G ─┬─ SWEEP ─ P1.1 ─ P1.1R ─ P1.1G ──────────────────────────┐
REV1 ──┴────────┘          ├─ V5 ─ V5R ─ V5G ─ PSYNC ─ PREV ─ PLAN2G ─┬─ P1.2a ─ P1.2b ─ P1.3 ─┤
                           │                                          ├─ P1.4a ───────────────┤
                           │                                          └─ P1.4b ─┬─────────────┴─ P1.5 ─ P1.6
                           └─ P2.1                                              │
QRET ─ PRESERVE ─ SCAN0                                                         │   P1.6 ─┬─ P1.7a ─┐
                                                                                │         ├─ P1.7b ─┤
                                                                                │         └─ P1.8 ──┤
                                                                                └── P1.9a ◄─ P1.8   │
                                                                          P1.9a, P1.7a, P1.7b ─ P1.9b ─ P1R ─ P1G
P1G, P2.1, QRET, SCAN0 ─ P2.2 ─ P3.1 ─ P3.2 ─ P3.3 ─ P3G ─┬─ P4
                                                          └─ P5          (P6 canceled from this run)
```

Graph ids: the skeleton keeps the short names; in the v2 graph nine parts carry a `-v2` suffix (§9's map:
`P1.2a-v2`, `P1.2b-v2`, `P1.3-v2`, `P1.7a-v2`, `P1.7b-v2`, `P1.9b-v2`, `P1R-v2`, `P3.2-v2`, `P3.3-v2`); the
edges are unchanged.

Status at v2 (2026-09-16): `QRET`, `PLAN1G`, `V5`, `V5R`, `V5G`, `P2.1` **done**; `PSYNC` in review; `SWEEP` in
progress in the v1.2 session; ready: `PRESERVE` (then `SCAN0`), `P1.1` once `SWEEP` is done. In the fresh
session on the v2 graph, `PLAN2G` is settled by the operator on the fresh-session receipt (§2, §8), after
which `P1.2a`, `P1.4a` and `P1.4b` are ready.

---

## 2. P0, the plan gate and the ADR track

### `QRET` — retention (operator question) — **answered**

Ruled 2026-09-15T20:00:11Z (`QRET·a1`, directive `verb: answer`, `run-plan004-v01`): §0.11's default adopted
— duration 90 days after `P3G` or ADR-004's supersession, whichever first; on supersession delete by default
or migrate under reviewed re-admission; deletion removes every copy and is recorded in §6, leaving counts,
digests and identities; covered paths as §0.11 lists them. The ruling is copied into §6. `PRESERVE` is ready.

### `PLANW`, `REV1`, `REV2` → `PLAN1G` — **done**

`PLANW` is this plan's author task through v1.2: attempt 1 (v1) and attempt 2 (v1.1) were `rejected` by
`REV1·a3` and `REV2·a1`; attempt 3 (v1.2) was accepted by `REV2·a2` (ACCEPT WITH CORRECTIONS, six
corrections applied and named in `PLANW·a3`'s receipt). **`PLAN1G`** (operator; deps `PLANW`, `REV1`,
`REV2`) was settled 2026-09-15T20:00:11Z on that verdict (review sha256 `943a59d2…`, plan sha256
`7d272108…`). v2 is authored under `PSYNC`, not `PLANW` (§0.10 (a): `PSYNC` ─ `PREV` ─ `PLAN2G`).

### `PRESERVE` — archive the prototypes (½ day)

Deps `QRET`. **Archive first, run nothing, delete nothing.**
1. Add `.motoko/eval-corpus/` to `.gitignore` **before** copying; `git check-ignore
   .motoko/eval-corpus/example` exits 0.
2. If `.motoko/eval-corpus/_archive/adr004-prototypes/` already exists, **stop** (no clobber). Otherwise
   copy, preserving relative paths: `../motoko_agent-mem/scripts/dst/mem_journal_replay.ail`,
   `mem_growth_probe.ail`, `mem_canonical_bench.ail`, `mem_editfile_probe.ail`;
   `../motoko_agent-mem/.motoko/memfix/` as found; this repo's untracked
   `scripts/dst/mem_canonical_bench.ail` and `mem_growth_probe.ail`; the v3/v4 review evidence directories
   `…/0dc4f7fe-…/scratchpad/codex-review/` and `codex-review-v4/`. A missing source is recorded by path.
3. `MANIFEST.sha256` (`sha256sum` format, **paths relative to the archive root**) inside the archive, and a
   tracked copy at `.agent/projects/013_core_architecture_for_dst/evidence/adr004-p0/MANIFEST.sha256`.
   `exposure.jsonl` in the archive records this agent.

**Gate.** `cd <archive> && sha256sum -c MANIFEST.sha256` clean; `find .motoko/eval-corpus -type d ! -perm
700` and `-type f ! -perm 600` both empty, **including every parent created**; `git status --porcelain`
shows no corpus path. **Commit:** `ADR-004 D8 P0: preserve the prototypes, ignore the corpus`.

### `SWEEP` — the precondition (½ day, heavy, record)

Deps `PLAN1G`. `make dst DST_JOBS=1` at HEAD (named). Before: `memory.current` < 12 GiB, no other heavy
run. §6 record per §0.1 and §0.7. A new unexplained red: `SWEEP` settles `done` with the red recorded, and
`P1.1` waits for an operator directive.

### `SCAN0` — heuristic pre-scan of the dev candidates (½ day, read-only, record)

Deps `PRESERVE`. **A heuristic reading, never an admission, and never a reason to relax a policy.** v5 D6
keeps body-16 as a stated heuristic over every occurrence of the 23 prefixes, `CredentialBearingName`
report-only, so the reading below is v5's, not a draft of it.
1. Re-derive r2.1's per-component counts (seed, retained script, retained tool outputs): raw
   `ProviderTokenLiteral` and `OpaqueHighEntropy`, `PrivateKeyBlock`, `JsonWebToken`, `UrlUserinfo`,
   body-16 refusals over **all** occurrences of all 23 prefixes, and the report-only sites (the review's
   four tool-output prefix sites 0, 96, 195, 228, maximum body 6). Confirm ADR-004 v5 D6's recorded counts
   (seed refusals at 1, 78, 86, 98, maximum run 24; the v5 review §3.10 re-confirmed them against `S4/scan_v4.txt`)
   or report the difference.
2. Locate `session_1789293423477-2e87f61dff66d42e`'s journal (`.motoko/sessions/<id>/journal.jsonl`,
   `.motoko/logfile/`, then the archive) and scan its first 57 turns the same way. Record which components
   could not be scanned and why.
3. Output in `.motoko/eval-corpus/_scan0/` (0700/0600); this agent in `_scan0/exposure.jsonl`. §6: counts,
   indices, absent data — nothing else.

### `V5` → `V5R` → `V5G` — **done**

**`V5`** (author task; deps `PLAN1G`): commits `9615bb4` (v4 + the eight review documents, by explicit path),
`21c1728` (v5 alone: the nine required changes as a v4→v5 retraction block with decision text and the
contract or test each implies, every v1.2 marker of §5 answered in a table, re-pinned to `3920814`), and
`988a863` (the review's corrections). **`V5R`** (`V5R·a1`, read-only, brief `BRIEF-adr004-v5-review.md`):
run with **claude**, Codex being unavailable in this container, and named `REVIEW-adr004-v5-verdicts-claude.md`
so the provenance stays honest — **ACCEPT WITH CORRECTIONS**, no v6: C1 the `Parked` row's parenthetical
(the turn preceding a park is the call-free stop-class call k; the segment ends at k−1); C2 the provider seam
counts `ProviderIdentity` records itself (`provider_calls_in` is private), `{ base | … }`, "structurally
equal prefix"; C3 the digest span rule beside the two `recording_ports` hashes; C4 the header names five
changed modules including `derive.py`; C5 D5's member list is the reviewed **starting set**, the transitive
names of review §3.8 added; C6 the checker paragraph carries P1.4b's literal-aware brace rule; cosmetic
`stub_step.ail:488–505`. `V5·a1` settled `done` on that verdict with the corrections in `988a863`.
**`V5G`** (operator) settled 2026-09-16T06:30:00Z: corrections accepted as applied; the D8 ruling on M15
recorded — `AdmissionCheck` near-misses satisfy the revised per-check requirement, the inapplicable rows
stand as reasoned; status Accepted (the one-line flip is in `PSYNC`'s commit). The review's PSYNC notes —
`tool_outcome_record :2133`, the C4 module list — are applied in §0.9.

### `PSYNC` → `PREV` → `PLAN2G`

- **`PSYNC`** (1 day, docs, author task; deps `V5G`, `PLAN1G`) — **this document.** Every v1.2 marker
  replaced by v5's decision; P1–P3 re-checked against v5 at HEAD; deltas and the id map in §9; the v2
  **operator** graph written to the **new file** `.dagr/run-plan004-v2.json` (run id `run-plan004-v02`),
  never by editing `run-plan004.json`: a part whose scope, deps or criteria changed got a **new id**
  (`<id>-v2`), and the file's `supersedes` object, its opening `note` event and each renamed task's `note`
  name the v1.2 id it supersedes. Settled history stays in `run-plan004-v01`; v2 carries **one summary
  attempt** per terminal task (id `<task>·a1`, evidence `reported`, receipt naming the v01 attempts and their
  evidence) and no event, policy or attempt copied from v01 — the shape a producer seeding from it would build
  (`dagr.ail:223–246`). `dagr check --strict --json` → `[]` (§6). **Commit:** `PLAN-004 v2: re-grounded on
  ADR-004 v5` — this file, ADR-004's status line, `BRIEF-adr004-v5-review.md`,
  `REVIEW-adr004-v5-verdicts-claude.md`, and the graph copied to `evidence/plan004-v2/run-plan004-v2.json`
  (`.dagr/` is ignored). The author attempt stays open until `PREV`'s verdict (§0.10 (a)1).
- **`PREV`** (½–1 day, read-only; deps `PSYNC`): v2 against v5 at `988a863`, and the v2 graph against v2's
  text (§9's map, the summary attempts, every renamed part's criteria); output
  `REVIEW-plan004-v2-verdicts-codex.md` — Codex `gpt-5.6-sol` if available, else claude with the file
  named `-claude-`, as `V5R` was, and the receipt says which.
- **`PLAN2G`** (operator; deps `PSYNC`, `PREV`): `PSYNC` `done` by an accepting verdict; the v2 graph
  strict-clean; the running Motoko session ended with a handoff; and the **fresh-session receipt** (§8):
  the new session's marker file names the v2 path, its first `Delegate` reply shows `dagr_task` linked, and
  its producer run file contains v2's task ids. `PSYNC` and `PREV` are settled in v01 by the running session;
  the fresh session mirrors each as one summary attempt in v2 from v01's receipts, then the operator settles
  `PLAN2G` **in v2** on the receipt above — the v01 session has ended by then, and v2's only writer is the
  fresh session. Every P1 part below except P1.1/P1.1R/P1.1G depends on it there.

---

## 3. P1 — build (D8 step 2)

### P1.1 — the `PortedWorld` variant, line-neutral (½ day, core, author task)

Deps `SWEEP`. Graph id `P1.1`, unchanged. Joins verified at `3920814` (v5 D2; re-verified by the v5 review §3.9, anchors and bridge span included):

| file:line | join |
|---|---|
| `src/core/test/stub_step.ail:69` | add `\| PortedWorld(Ports, WorldState)` to the sum **before** the trailing `--` comment |
| `src/core/session.ail:195` | add `PortedWorld` to the one-line constructor import |
| `src/core/session.ail:1545` | append `, PortedWorld(p, w) => { ports: p, world: w }` after the `GeneratedWorld` arm (function starts `:1532`) |
| `scripts/dst/ledger_parity_dst.ail:73` | add `PortedWorld` to the constructor import |
| `scripts/dst/ledger_parity_dst.ail:435` | append `, PortedWorld(_, w) => w.ordinal` after the `Ported` arm |

`src/core/test/scripted_ports.ail:30–35` untouched; the commit message states its non-coverage of
world-bearing providers. **Gate:** `wc -l` unchanged (915 / 6320 / 642); `git diff --unified=0` shows
exactly five `-` and five `+` content lines, at the five sites; `sha256sum` of `sed -n 1085,1474p
src/core/session.ail` equal before and after; `ailang check` **on the edited files** green; `make anchors`
(every pin, including `stub_step.ail:203`), `make driver_leaf_inventory`, `make ledger_parity`, `make
strict_replay` green. **Commit:** `ADR-004 D2: the PortedWorld test-provider variant, line-neutral`.

### P1.1R → P1.1G

`P1.1R` (½ day, Codex, read-only): verdict on — diff is exactly the five joins; line counts; every
`anchors.sh` pin; bridge-span bytes; type-check; nothing else changed. `P1.1G` (orchestrator-checked; deps
`P1.1`, `P1.1R`): `P1.1` `done` by an accepting verdict (§0.10). `P1.5` depends on `P1.1G`.

### The D8 P1 matrix — case → test → observed result

Each row names the part whose commit lands it. **Expected values are frozen separately**, in
`src/eval/journal/testdata/MATRIX.expected.tsv`, written by the part that lands each case and reviewed with its
commit: `case_id`, `test_name`, `expected_verdict`, `expected_first_finding`, `expected_position` (entry position,
call index or interaction ordinal, or `aggregate:<family>`). **`make eval_matrix`** runs the suites and writes
`MATRIX.tsv` with `case_id`, `test_name` and **only observed fields** — `observed_verdict`,
`observed_first_finding`, `observed_position`, `commit` — never copying an expected value. `P1R` and `P1G` join
the two files on `case_id` and require verdict, first finding and position to be equal on every row.

**Independent expectations.** Synthetic fixtures are built by `src/eval/journal/testdata/gen_fixtures.py`
(Python, `hashlib`), a third implementation of the append-chain frame, so fixture digests do not come from
the evaluator's copies; on real entries A1's expectation is the `digest_after` values the live host wrote
into the snapshot.

| # | Family | Cases (each refused/divergent + clean twin) | Part |
|---|---|---|---|
| M1 | D1 source refusals | `ChainBreak`, `MalformedEntry` (incl. a stray `wake` — no open park, an answered park, another request's id: the fold's refusal at `request_id`, `journal.ail:1603–1614`), `UnknownEntryType`, `UnknownSchema` — each asserting the refusal's entry position | P1.2a |
| M2 | D1 attribution/association | `DuplicateOrAmbiguousCallId`, `UnexpectedToolResult`, `MalformedToolArguments`, `Association` (extra prepared call; extra assistant; `thinking.tool_calls` ≠ call count), `ContinuationStart` (a suspended continuation **and** a wake-opened run, `SeedParked`), `EmptySegment` — each with position | P1.2b |
| M3 | Cutoffs (D1's table) | `Completed`, `Suspended`, `Resumed`, `SettingsChange`, `RunStarted`, `Exit`, `EofWithoutRunFinished`, `Parked` (before the call-free stop-class call k preceding the park, `EndSuspended(k−1)`; the wake child and the injected wake message inside the cut), `ProviderRetry`, `UserMessage`, `HistoryReplaced`, `ReplacesPrevious`, `IncompleteToolBatch`, `CallFreeToolCallsFinish`, `BlankStop`, `HybridExtraction`, `RuntimeStatusCall`, `StopBeforeEnd` (the one post-turn cutoff: keeps call k, N = k, `EndFinalize(model_stop)`) — each asserts the resulting selector, N, expected end, genuine or synthetic | P1.3 |
| M4 | Call shapes (D1's six-shape procedure) | continuation; incomplete batch; call-free `finish_reason = tool_calls` → `CallFreeToolCallsFinish`; blank stop → `BlankStop`; stop call → `EndFinalize(model_stop)`; a `hybrid-step-` result → `HybridExtraction`; the native-call predicate asserted once over seed + appends before the first stop call when `hybrid_tools` is recorded true — true admits, false → `Refused(HybridPredicate)` | P1.3 |
| M5 | Configuration (D1's settings table) | every served value incl. `MOTOKO_EXIT_MANIFEST` and `MOTOKO_CAPTURE_FAILED_PAYLOAD` `""`, `MOTOKO_PERSIST_RETRIES` `"0"`, explicit `MOTOKO_PROFILE_DIR = .motoko/eval-profile` with the `FsFile` at exactly `.motoko/eval-profile/config.json`; context limit `n > 0` → `ProfileWindow(n)`, `"disabled"` → `ProfileDisabledDeclared`, missing or non-positive → `ProfileMissed` and a `MOTOKO_MODELS_FILE` read the witness refuses; the `provider_api_model` copy equal to the live function incl. non-idempotence; the excerpt's logical model equal to the recorded one | P1.3 |
| M6 | Digests | each copy equals the candidate function at A on fixtures, incl. an image and `make[N]`, and equals `gen_fixtures.py`'s digest | P1.4a |
| M7 | Protected checker | P1.4b's self-test list | P1.4b |
| M8 | Seams fail-closed (v5 D2) | provider empty script: the harness's exhausted record (payload `{ "served": false }`, `OutcomeOk`, class `""`, chunks `[]`, advance 0, deadline −1) and a non-retryable `Err`; tool empty queue: `tool_outcome_record`'s `ToolFailed` arm field for field (`OutcomeFault`, `fault_class_tool_failed()`, code `replay_unrecorded_invocation`) and **no live effect** (a sentinel file the live arm would create is absent); correlation mismatch; exactly-one-append (structurally equal prefix + one) on each seam | P1.5 |
| M9 | Admission A5/A6/A9/A9b | malformed frame; wrong end (budget vs stop; exhausted marker present); each A9b identity class false-but-nonblank → finding; blank field → `validate_manifest` | P1.6 |
| M10 | Admission A1–A4 + locations | A1 seed-digest tamper against the snapshot's recorded digests; A2 one-byte append change; A3 payload digest and model conversion; A4 JSON-inequal argument change (JSON-equal reorder passes); each finding's typed `Location` (first position or aggregate) | P1.7a |
| M11 | Admission A7/A8 + census (v5 D3) | witness under- and over-count; a fault-path env read (`MOTOKO_CAPTURE_FAILED_PAYLOAD` on a non-retryable failure) counted in its own column; wrong obligation (`NoReplay` at admission) or metadata (`replay_metadata_of(manifest)`); the **decision count** asserted equal to `2N + 1` (`EndSuspended(N)`) / `2N` (stop at N) and used as `decision_budget`, `retry_budget` 0; every census row of D3's table asserted **zero by name** on the T0 fixture with a non-zero twin per row; `family_evidence` recorded unchanged with `CheckpointHistory` evaluated-but-vacuous | P1.7b |
| M12 | Scan (v5 D6) | `PrivateKeyBlock`, `JsonWebToken`, `UrlUserinfo`; body-16 on a **later** occurrence; 6-character body reported; `CredentialBearingName` report-only; one hit per component (snapshot, excerpt, program identity/projection/payload/chunks, env, files, metadata, derived output → refused); report contains no body | P1.8 |
| M13 | Candidate refusals | `InadmissibleCandidate` by path and by intent; `EvaluatorTouched`; `ProtectedRegionTouched` (span hash, missing, duplicate, moved symbol, protected import statement); `PreflightMismatch` per identity class (incl. a project module resolving outside the assembled root, a `pkg/` path outside the pinned package root, a warm cache); `GuardTripped`; `ProgramUndecodable` | P1.9a |
| M14 | Divergence families | `WrongKind`, `WrongOrigin`, `UnsafeIdentity`, `ProjectionDiffers`, `OutcomeDiffers`; `ProgramExhausted` and `UnusedInteraction` by **direct log-length mutation**; the exhausted-marker case asserting its **actual** first finding (`ProgramExhausted` only past the expected log's end, else the projection/outcome mismatch at that position, an earlier mismatch first) with the marker's position in the envelope; `ReconstitutionFinding` (K1); `DiscoveryFinding` incl. prepared ≠ recorded (K3); `Violation` (K4) and census mismatch; `FrameMismatch` (K5); `EndMismatch` (K6); `ChainMismatch` (K7) — **each with its first finding and typed `Location`**; no score after any K failure | P1.9b |
| M15 | **Near-misses per refusal family** (ruled by v5 D8 and `V5G`: satisfied as the per-check known-failing cases, not owed per family) | see the table below | the family's part |

**M15 — ruled.** v4's sentence "one known-divergent and one known-refused case per refusal family" is
**revised** in v5 D8 ("The P1 test contract"): per refusal family one refused case at a pinned location plus a
clean twin; per cutoff one selector/N/end case; per check A1–A9, A9b and K1–K7 one known-failing case with its
first finding and location pinned plus a clean twin, one per `ReplayMismatch` variant; per seam arm one; one
witness under- and one over-count and one prepared ≠ recorded; per census row zero-by-name plus a non-zero twin;
one vacuous family reported through `family_evidence` unchanged. The near-miss rows below — an input that first
**passes its own family's refusal** and every check before the named one, both asserted in the same test, and
whose defect a later check catches **at a pinned position** — are **kept** as the known-failing case for the
check that catches them and as the proof of a check-ordering assumption; they are **not required per refusal
family**, so every row marked inapplicable is **satisfied by its recorded reason** in `MATRIX.expected.tsv`
(`V5G`, 2026-09-16). Two rows were settled by v5 itself: park/wake is inapplicable because `Parked` is a cutoff
(its M3 case asserts the selector) and a wake-opened start is `ContinuationStart` (M2); `ProtectedRegionTouched`
is retained as the closure's regression test. At admission a near-miss's finding is
`Refused(AdmissionCheck(Ak, location))`, a refusal, not the candidate's `Diverged` constructor.

| Family | Near-miss (passes the family's refusal and all earlier checks) | Expected first finding |
|---|---|---|
| `ChainBreak` | a consistently re-chained snapshot whose tool result at call k is altered, where **call k+1 exists and is an evaluated continuation** (never the terminal call) | A1, A2, A4 pass; `AdmissionCheck(A3)` at `Call(k+1)` (request digest against the live excerpt) |
| `UnexpectedToolResult` | a correctly attributed result at call k with one content byte changed; call k+1 exists | `AdmissionCheck(A3)` at `Call(k+1)` |
| `MalformedToolArguments` | decodable arguments at call k with one value changed; call k+1 exists | `AdmissionCheck(A3)` at `Call(k+1)` |
| `MalformedEntry` | a well-formed entry of the same type with changed message content, chain recomputed; the next evaluated call exists | `AdmissionCheck(A3)` at that call |
| `DuplicateOrAmbiguousCallId` | unique ids with two results' order swapped — the test **first asserts** what D1's ordered association (P1.2b) does with it | if association accepts: the first of the seam's `ToolCorrelationMismatch` → `AdmissionCheck(A2)`, pinned by the fixture; if association refuses: **inapplicable**, recorded as such (v5 D8: the conditional row stands as written) |
| `Association` | a **same-run**, correctly associated excerpt whose `payload_digest` at call k is altered | `AdmissionCheck(A3)` at `Call(k)` |
| `UnknownEntryType` | — | **inapplicable**: the nearest decodable input is a known type, and a known type in-segment is either a cutoff (M3) or a content change (the `MalformedEntry` row) |
| `UnknownSchema` | — | **inapplicable**: an entry under an undecodable schema cannot be read |
| `ContinuationStart`, `EmptySegment` | — | **inapplicable**: no evaluated call exists |
| `HybridPredicate` | — | **inapplicable**: the predicate is asserted once at admission and no later check depends on it; `hybrid-step-` results are cut (M3) |
| park/wake | — | **inapplicable** (v5 D1/D8): `Parked` is a cutoff, asserted in M3; a wake-opened start is `ContinuationStart` (M2); a stray `wake` is `MalformedEntry` (M1) |
| Scan refusal | a 15-character body | reported and admitted; **inapplicable** as a divergence (the scan does not affect the replay) — satisfied by this reason (`V5G`) |
| `InadmissibleCandidate` (path) | a candidate editing a **named permitted file** (chosen with the fixture) so that one message changes | path refusal passes, protected check passes, K0 passes (all asserted); `Diverged` `ProjectionDiffers` at the first affected call |
| `InadmissibleCandidate` (intent) | declared and reviewed resource-only, but changes one output | same assertions; `Diverged` at the first affected interaction |
| `EvaluatorTouched` | a file outside §0.5's evaluator paths **and** outside D3's refusal list whose edit changes a tool invocation, if the fixture can name one | as the path row; otherwise **inapplicable** (satisfied by that reason, v5 D8) |
| `ProtectedRegionTouched` | an edit outside every protected span that changes a recorder's input, searched for against v5 D5's starting set | K0 passes; `Diverged` at that interaction — **reported as a missing closure member** (v5 D5: not a checker defect); if the search finds no such edit, that is the row's success, recorded **inapplicable with the search stated** (v5 D8) |
| `ProgramUndecodable` | — | **inapplicable**: the program is pinned by the entry and K0 compares corpus hashes, so a candidate cannot change it; the reachable counterpart, a candidate whose run emits a different outcome against the valid program, is M14's `OutcomeDiffers` |
| `PreflightMismatch`, `GuardTripped` | — | **inapplicable**: identity and resource refusals have no replay |

### P1.2a — reader I: path, strict decoding, seed (1 day, D1) — graph id `P1.2a-v2`

Deps `PLAN2G`. `src/eval/journal/reader.ail`: `RunSelector { leaf, run_id, start, end: EndAt |
CutoffBefore }`; path leaf→root by `parent_id` under ADR-003 D4 strictness; `start` is the first evaluated
call's assistant entry; the seed is the fold of the path up to the entry before `start` (leading user entries
after `run_started` included — r2.1's 1055), dangling-call repair applied only for the seed. **Decoders and
the fold are evaluator copies** of `journal.ail`'s at A, **not imports** (v5 D5 "The evaluator": the fold runs
inside the measured process as common overhead, and an import would pull `journal.ail` into the protected
closure, excluding exactly the fold and decoder changes D3's class admits); each copy records the SHA-256 of
the source span it copies, checked by P1.4b's tool so that drift is **reported**, not refused. `park` and
`wake` decode (twelve entry types, `journal.ail:1253–1256`); the reader treats a `park` as the `Parked`
cutoff (P1.3's), a wake-opened start as `ContinuationStart` (P1.2b's) and a stray `wake` as
`MalformedEntry` (the fold's refusal at `request_id`, `:1603–1614`). Tests: M1, M15's rows for M1, an
r2.1-shaped leading-user seed, and fold equality against `journal.ail`'s `fold_journal` (`:1679`) and
against `gen_fixtures.py`. **Commit:** `ADR-004 D1: the reader — path, strict decoding, seed`.
**v2:** supersedes v1.2's `P1.2a` — the park/wake refusal row left M1 for M3, the stray-wake case was
added, and copies-not-imports was decided (§9).

### P1.2b — reader II: excerpt, association, arguments (1 day, D1) — graph id `P1.2b-v2`

Deps `P1.2a`. The excerpt reader (D1's event types only, with source positions, both `session_start`
shapes); ordered association from the banners (the k-th `provider_call_prepared` is call k, its `thinking`
the next with the same `step`, its journal counterpart the k-th assistant `history_appended` not counting
`replaces_previous`; `thinking.tool_calls` = the assistant's call count); canonical JSON arguments (compact,
keys in source order; JSON equality). `ContinuationStart` covers both a suspended continuation and a run
opened by a consumed wake (`SeedParked`, `session.ail:4271`, `:5531–5536`, `:5577`). Tests: M2 and M15's
rows for M2. **Commit:** `ADR-004 D1: the excerpt and ordered association`. **v2:** supersedes v1.2's
`P1.2b` — the wake-opened `ContinuationStart` case was added (§9).

### P1.3 — reader III: stopping contract, cutoffs, configuration (1½ days, D1) — graph id `P1.3-v2`

Deps `P1.2b`. The stopping contract as v5 D1 states it — the **six-shape classification** over the recorded
call's shape (continuation; incomplete batch; call-free `tool_calls` finish; blank stop; stop call; hybrid
extraction in the source), the native-call predicate asserted once when `hybrid_tools` is recorded true, and
the two expected ends `EndSuspended(N)` / `EndFinalize(model_stop)`; the full cutoff table incl. `Parked`
(before the call-free stop-class call k preceding the park, C1), `CallFreeToolCallsFinish`, `BlankStop`,
`HybridExtraction`, `RuntimeStatusCall` and the post-turn `StopBeforeEnd`; the refusal `HybridPredicate`;
the logical model from `settings` entries, `BootInputs`, and **the T0 settings table as v5 pins it** — both
ambient keys `""`, `MOTOKO_PERSIST_RETRIES` `"0"`, explicit `MOTOKO_PROFILE_DIR` with the profile `FsFile`,
the context-limit encoding (`n > 0` / `"disabled"`; `ProfileMissed` refused by the witness),
`checkpoint_enabled` false, `max_cost_millicents` 0; an evaluator copy of `provider_api_model`
(`session.ail:272–293`) pinned by hash; `expected.decisions` = `2N + 1` / `2N`; `unreproduced` and
`omissions`. Tests: M3, M4, M5. **Commit:** `ADR-004 D1: the stopping contract, cutoffs and T0
configuration`. **v2:** supersedes v1.2's `P1.3` — four cutoffs, one refusal, the six-shape procedure,
the pinned settings values and the decision count were decided by v5 (§9).

### P1.4a — private digests (1 day, D2/D5)

Deps `PLAN2G`. `src/eval/journal/digests.ail`: canonical payload, system prefix, raw frame, canonical-JSON
arguments — copies of the functions at A, each with the SHA-256 of its source span. Tests: M6. **Commit:**
`ADR-004 D2: the private digests`.

### P1.4b — the protected-source checker (1½–2 days, D5)

Deps `PLAN2G`. `tools/eval_protected/` (Python). Contract:
- **Lexer.** AILANG-aware: `--` line comments; string literals with escapes and `${…}` interpolation,
  nested; braces and parentheses counted outside literals and comments. An unterminated literal or an
  unbalanced brace or parenthesis is a **hard error** (exit 2, file and line).
- **Import statements, not lines.** An import statement runs from the `import` keyword through its module path,
  an optional `as <Alias>` (`src/core/ports.ail:12–14`; `src/core/fs_node.ail:69–70`), and, when a `(` follows,
  through the matching `)` — across lines (`src/core/test/stub_step.ail:28–33`; `src/core/ports.ail:60–67`) and
  with several statements on one line (`src/core/test/stub_step.ail:44`, three statements). Each protected file
  has **one aggregate `imports` span per contiguous run** of import statements: from the first byte of the first
  line holding an import statement to the last byte of the last such line, comments and blank lines between them
  included. Per-statement records are kept for the report (which statement changed); **only the aggregate span is
  hashed and takes part in the overlap check**, so no span is nested in another.
- **Declaration spans.** A braced declaration (`func`, `pure func`, `export func`, a braced `type`/`export type`)
  runs from its first line's first byte to its matching `}`, **extended through a following `deriving (…)`
  clause** when the next non-blank, non-comment token is `deriving` (`src/core/types.ail:81–86`). A **non-braced**
  type (a multi-line union: `src/core/types.ail:62–70`, `:88–101`; `src/core/dst_interaction.ail:59–95`) runs to the
  last non-blank line before the next line that begins at column 0 with a declaration keyword (`import`, `func`,
  `pure`, `export`, `type`, `module`), a column-0 `--` comment followed by one, or EOF. **That rule is a heuristic,
  not a parse**: before a manifest is generated, every protected non-braced span is checked against the parser by
  type-checking a scratch copy with exactly that span removed and confirming that `ailang check` reports that
  declaration's names — and no other declaration's — as unbound. Two **different** declarations' spans
  overlapping is a hard error, as are a missing or duplicate symbol.
- **Hash.** SHA-256 over the **original bytes** of each span; comments and whitespace inside a span are protected,
  outside every span they are not.
- **Manifest.** JSON per span `{ file, symbol, kind, sha256, source_commit }` plus the protected file list;
  `gen --at <commit> --symbols <list>` reads `git show <commit>:<path>`, never the working tree. The symbol
  list is ADR-004 v5 D5's **reviewed starting set** (C5) — in `ports.ail` the recorder, both codecs and
  their helpers (`tool_calls_json`, `tool_calls_of`, `bool_field`, `str_field`, `int_field`, `json_array`),
  `world_tool`, `live_tool_outcome`, `scripted_tool_outcome`, `recording_tool`, `tool_outcome_record`,
  `provider_outcome_record`, `scripted_step_ai_error`, `scripted_step_faults`, the clock, env, file, approval,
  wake (`cursor_wake` included), mutation and effect ports `recording_ports` and `ports_shape_probe` bind, and
  the named types; in `stub_step.ail` `recording_ports`, `recording_model_step`, `scripted_to_step_result`,
  `terminal_step`, `play_chunks`, `scripted_chunks`, `chunk_records`, `provider_calls_in`, `dispatch_step`,
  the `StepProvider` sum; in `session.ail` `provider_api_model`, `ported_provider`, `dispatch_step`'s call
  site; in `dst_fault_catalogue.ail` the class literals and `provider_error_is_retryable` — plus the imports
  region of each file and every type declaration a listed function names. The manifest **is** the closure
  the entry pins; its completeness is reviewed at `P1R`/`P1G` (v5 D5: "reviewed, not derived"), and an edit
  outside every span that changes a recorder's input is a missing member reported to the next ADR revision,
  not a checker defect (M15's `ProtectedRegionTouched` row).
- **Decision is C-side.** `check --manifest M --tree C` recomputes every span **at C** by symbol and refuses
  (exit 1, naming each) when a protected symbol is missing, duplicated, moved to another file, or its span or
  any import statement or import region hashes differently. A new declaration inserted between spans is
  allowed unless it duplicates a protected name. `diff --parent P --candidate C` only **names** spans a hunk
  overlaps, for the report; it decides nothing.
- **Self-test** (`make eval_protected_selftest`), on **mutated copies in a scratch directory** with the
  manifest generated independently from a commit: whitespace inside a projection string literal; one token in
  `tool_outcome_record`; a name added inside a multi-line import's parentheses; a second import joined onto
  an import line; an `as` alias changed; a comment inside a span; a multi-line non-braced type changed on its last line; a `deriving` clause changed; a protected
  function moved to another file; a protected function renamed (missing) and re-added under its name elsewhere
  in the file (moved within file: span hash unchanged → allowed); all detected except the last; a change
  outside every span (not detected); `${` inside a string containing `}` (spans unchanged); unterminated
  string, unbalanced parenthesis, missing symbol, duplicate symbol, overlap of two different declarations (each exit 2); the parser cross-check on every non-braced span.

**Commit:** `ADR-004 D5: the protected-source checker`.

### P1.5 — the world builder and the two seams (1½–2 days, D2)

Deps `P1.1G`, `P1.3`, `P1.4a`, `P1.4b`. Graph id `P1.5`, unchanged. `src/eval/journal/world.ail`:
`JournalWorld` → `WorldState` as v5 D2 builds it (script from the calls — prose, tool calls, tokens, the
excerpt's finish reason, chunks `[]`, `advance_ms` 0; tools from the results in journal order, `exit_code` −1,
`duration_ms` 0; env = the recorded values and the T0 settings with `MOTOKO_EXIT_MANIFEST` and
`MOTOKO_CAPTURE_FAILED_PAYLOAD` present and empty; clock the declared epoch; `files` = the one `FsFile` at
`.motoko/eval-profile/config.json` holding D1's context-limit config; `approvals: []`, `wakes: []`).
`src/eval/journal/seams.ail`: `{ base | model_step: eval_model_step(base), tool_exec: eval_tool_exec(base) }`
with `base = recording_ports(rt)`, by guarded delegation (D2): the empty arms construct the complete
fail-closed records themselves from exported parts — provider: `ProviderIdentity("loop_v2", k, api_model)`
with **k = the count of `ProviderIdentity` records in `state.log`, computed by the seam** (C2;
`provider_calls_in` is private), the `replay=exhausted` projection, deadline −1 and exactly the harness's
exhausted record `{ advance_ms: 0, chunks: [], payload: encode_exhausted_provider_outcome(), status:
OutcomeOk, fault_class_id: "" }`, returning a non-retryable `Err(replay_exhausted)`; tool:
`ToolIdentity("loop_v2", call_id, name)`, the `replay=unrecorded` projection, deadline `inv.timeout_ms`, and
`tool_outcome_record`'s `ToolFailed` arm field for field — `{ advance_ms: 0, chunks: [], payload:
encode_tool_outcome(o), status: OutcomeFault, fault_class_id: fault_class_tool_failed() }` with `o =
ToolFailed({ tool_call_id, code: "replay_unrecorded_invocation", message })`, clock unadvanced. The non-empty
arms delegate to the exported recorder, assert the log is the old log plus exactly one interaction
(**structurally equal prefix**), and replace only `request_projection` (`payload=<D> system=<S> raw=<R>`;
`args=<digest>`). No private helper, no new export. Tests: M8; `world_state_of` over the recorded log rebuilds
the script and tool queue. **Commit:** `ADR-004 D2: the journal world and the guarded-delegation seams`.

### P1.6 — the admission run, the program, provenance (2–2½ days, D2/D3)

Deps `P1.5`. `src/eval/journal/admission.ail` and the runner's `admit` mode. The run:
`run_v2_session_traced` (`session.ail:4423`) with the recorded `BootInputs`, the logical model, the seed, a
throwaway `workdir`, `step_budget = N`, `max_cost_millicents: 0`, an empty-registry `ExtRuntime` with
verification disabled, and `PortedWorld(ports, world)`; framed with `WORLD_RUN_BEGIN`/`END` and an empty
final pending queue.

**Provenance: collected, then checked against a different source** (v5 D2/D3's A9b adopt this table by reference; v5 review §3.5). `scripts/eval/journal_replay.sh`
collects `identities.json` **before** the run; A9b checks each field **before** admission against the comparator in the third column — a different code path where one exists, otherwise a reviewed pinned record or a consistency check, as each row says — and again after the run for temporal change. `validate_manifest(m, driver_only())` (`dst_profile.ail:1535–1573`) checks presence, profile and
rule versions only; `dst_driver_only.ail:1097–1123` takes revision, toolchain, ABI, configuration, the sets
and the scan commit as caller inputs; `strict_replay_dst.ail:631–633` fills them with fixture literals.
None of those is used as a truth source.

| field | collected by `journal_replay.sh` | independent check (A9b) |
|---|---|---|
| `source_revision`, `scan_root_commit` | `git -C <A> rev-parse HEAD`; refused if `git status --porcelain` shows tracked changes outside the corpus (at `3920814`, `ailang.lock` is modified: it must be committed first) | `git -C <A> cat-file -e <rev>^{commit}` and the tree hash of the assembled A equal to `git rev-parse <rev>^{tree}` |
| `toolchain` | `ailang --version`, `sha256sum "$(readlink -f "$(command -v ailang)")"` | the binary SHA-256 pinned in E's record at `P1G`; before `P1G`, real admission is refused |
| `abi_version` | `version` in `packages/motoko-ext-abi/ailang.toml` (`:1–3`) | `version` of `sunholo/motoko_ext_abi` in `ailang.lock` (`:71–77`), a different file written by `ailang lock`. The lock's `interface_hash` is **not** a version: it is recorded as the package's interface identity and compared with the entry's pinned value at K0; no fresh interface recomputation — v5 D5 adopts P1.9a's contract, and `ailang lock` in v0.33.0 only regenerates the lock; it has no verify mode |
| `classifier_2_set`, `unrouted_fields` | `python3 tools/ext_call_inventory/derive.py --json` at A (the `make ext_call_inventory` target, `Makefile:3080–3082`, runs it **without** `--json`) | **not a second extractor**: `tools/profile_definition/check_fixtures.py`'s `derive()` runs the same script (`:35–37`). The comparator is the **reviewed pinned record** — the `classifier_2_set` and `unrouted_fields` literals in `scripts/dst/profile_definition_dst.ail` at A (`check_fixtures.py:25`), whose agreement `make profile_definition` enforces. The claim is narrowed to agreement with a reviewed record |
| `scan_roots` | the inventory's `--roots` default at A (`tools/ext_call_inventory/derive.py:480`: `src,packages`) | the profile's `scan_roots` (`src/core/dst_driver_only.ail:1065`), root for root; and every leaf in `SCAN_FILES` (`tools/driver_leaf_inventory/derive.py:187–192`) checked to lie inside those roots |
| `pkg/` packages | every `ailang.lock` entry (name, `source`, `path`, `version`, `interface_hash`) and the lock's SHA-256 | the entry's pinned package inputs and the effective-lock rule of P1.9a; a lock `path` is never itself an identity |
| `normalized_configuration` | canonical JSON of the reader's `RecordedConfig ++ T0Settings` | re-derived by `gen_fixtures.py`'s config reader from the snapshot's `settings` entries and the entry's T0 table |
| `profile_id`/`profile_version`, rule versions, `event_vocabulary_version` | the build's functions at A (`dst_driver_only.ail:1097–1123` derives these) | **consistency only, not independent truth**: `validate_manifest` compares them with the same `driver_only()` builder (`dst_profile.ail:1535–1573`) and `make profile_definition` checks the fixtures; the claim is narrowed to that |
| `generator_version` | `git -C ../motoko_agent-eval rev-parse HEAD`; before `P1G`, `<HEAD>-dev` | E's pinned commit; a `-dev` generator **refuses real-entry admission** |
| `extension_packages` | `[]` | the empty registry the run used |

The program: schema `/4`, `generator_id: "journal_admission"`, `initial_world` as D2, observed `bounds` as
data, `interactions` = `world.log`. Checks landed: **A5** framing, **A6** expected end with no exhausted
marker, **A9** round trip (`validate_program`, `validate_manifest`, `world_state_of`,
`reconstitution_balance`) and **A9b** provenance. Synthetic only. Tests: M9 plus three continuations →
`EndSuspended(3)` with `RunSuspended` and `suspended: Some`; a stop call → `EndFinalize(model_stop)`.
**Commit:** `ADR-004 D2/D3: the admission run, the program and its provenance`.

### P1.7a — source checks and the admission verdict (1½ days, D3) — graph id `P1.7a-v2`

Deps `P1.6`. A1 (the snapshot prefix folded by P1.2a's copy, checked against the **snapshot's recorded
`digest_after` values**, not against anything the admission derived); A2 (`final.history` = seed ++
appends, byte-exact, with the `HistoryAppended` chain and count); A3 (per call: `payload=`, `system=`,
converted model, `msg_count`, count, against the excerpt); A4 (invocations against the journal's decoded
calls, JSON equality). Finding locations are v5 D3's typed **`Location`** — `Interaction(ordinal)` (a
program position), `Call(k)` (A3, A6), `Source { source: Snapshot | Excerpt, position }` (A1, A2, A4),
`Aggregate(name)` (A5 frame totals, A7, A8) — never a sentinel where a tagged location exists. The mapping
onto `Admission = SourceFaithful { entry, calls: N, end, envelope } | Refused { Refusal |
AdmissionCheck(A1..A9, A9b, location) | ScanRefusal }`. **Comparands:** at admission, the parent's run
against the source; A2's function is reused unchanged as K7 in P1.9b against the entry. Tests: M10 and
M15's admission rows (`AdmissionCheck(A3)` at `Call(k+1)` and the like). **Commit:** `ADR-004 D3: source
checks and the admission verdict`. **v2:** supersedes v1.2's `P1.7a` — the two-shape location proposal
became v5's four-variant `Location`, and `AdmissionCheck` carries A9b and the location (§9).

### P1.7b — witness, invariant bridge, census (1½–2 days, D3) — graph id `P1.7b-v2`

Deps `P1.6`. A7: `DiscoveryWitness` built by the runner (provider calls from `ProviderCallPrepared`; tool
dispatches from queue consumption; explicit zeros for approvals, file writes/removes/dir makes and extension
effects; clock delta from the worlds; `expected_env_reads` per `driver_env_keys()` key with **v5 D3's
table** — 1 for the four policy-init keys, `MOTOKO_PROFILE_DIR` and `MOTOKO_SESSION_ID`; 0 for
`MOTOKO_CONFIG`, `MOTOKO_REPO`, `MOTOKO_MODELS_FILE`; T for `MOTOKO_TOOL_TIMEOUT_MS`;
`MOTOKO_EXIT_MANIFEST` 0/1 by end; `MOTOKO_CAPTURE_FAILED_PAYLOAD` 0, 1 only on the never-admitted fault
path — accepted-end counts separate from fault-path reads, each key asserted). A8:
`evaluate(execution_of(run, epoch, NoReplay, decision_budget, 0, 0, [], replay_metadata_of(manifest)))` —
`NoReplay` at admission (only `ReplayConsistency` unevaluated, stated), `replay_metadata_of(manifest)`
(`dst_profile.ail:1582–1588`), `decision_budget` = the entry's derived count (`2N + 1` / `2N`, one
`DecisionRecord` per `decide`, asserted equal at admission), `retry_budget` 0; `family_evidence` reported
unchanged; beside it the **sub-obligation census** of v5 D3's table — checkpoints, stream chunks, approval
reads/consumed, waits/parks/wakes, extension effects, retries, injected messages, hybrid extractions, file
writes/removes/dir makes, exit-manifest publications, capture reads, decisions, and the "not observed" row —
each a count with its route assumption, each asserted individually, the four words kept apart. Tests: M11.
**Commit:** `ADR-004 D3: the witness, the invariant bridge and the census`. **v2:** supersedes v1.2's
`P1.7b` — the obligation, metadata, budgets, the decision-count assertion and the thirteen census rows were
decided by v5 (§9).

### P1.8 — scan policy, entry, artifact (1–1½ days, D6)

Deps `P1.6`. Graph id `P1.8`, unchanged. `src/eval/journal/scan.ail`: the contextual policy over every component, as v5 D6
pins it (v1.2's proposal, confirmed): refuse `PrivateKeyBlock`, `JsonWebToken`, `UrlUserinfo`, and `ProviderTokenLiteral` with a
≥16-character body on **any** occurrence — a heuristic with stated false positives and negatives; report
everything else, `CredentialBearingName` included, by site, reason and count, never the body;
`dst_secrets.ail` unchanged. The artifact `"<schema>\ndigest\t<digest>\n<body>\n"` from `encode_body` and
`program_digest`, loaded by `load_program`; **no second codec**. The entry at `.motoko/eval-corpus/<entry>/`
(0700/0600): snapshot and excerpt with SHA-256, selector, expectations, T0 settings, expected end, program
artifact, witness, family and census record, envelope, identities, scan report, exposure log (with migrated
pre-entry rows, §0.6); derived output under `runs/`. Tests: M12; artifact → `load_program` → same digest; a
permission failure is a refusal, not a partial entry. **Commit:** `ADR-004 D6: the scan policy, the entry
and the program artifact`.

### P1.9a — candidate assembly, refusals, execution provenance, preflight (1½–2 days, D3/D5)

Deps `P1.4b`, `P1.8`. Graph id `P1.9a`, unchanged: v5 D5 ("Execution provenance") adopts this part's contract by reference, and the marker check and the residual gap are printed in every envelope (D3, D5). The runner's `candidate` mode over an entry, a parent P and a candidate C.
- **Ownership.** The runner creates the assembly worktree under `runs/<run-id>/tree` from C, owns and
  removes it; `candidate.json` (declared intent, parent, the reviewer who accepted the intent) is supplied by
  the operator or orchestrator, never generated by the runner.
- **Refusals before running** (M13): D3's path list; declared intent; `EvaluatorTouched` (C's diff against P
  touches §0.5 paths); `ProtectedRegionTouched` (`tools/eval_protected check` at C); guard record;
  undecodable program.
- **Assembly.** Evaluator paths copied from E over the tree; E, corpus and protected hashes checked before
  and after; assembly identity recorded (tree hash, E, any compatibility patch).
- **Execution provenance** — what compiled, and from where. (AILANG coordinates here are the **installed** source,
  `/home/motoko/.local/share/ailang` at `ae36986`.) `ailang` v0.33.0 reports no module-id → selected-file mapping:
  `DEBUG_LOADER=1` prints a search trace only when a load fails (`internal/loader/loader.go:468–475`), and the
  pipeline resolves each module's `File.Path` only for its internal `MOD011` collision check
  (`internal/pipeline/pipeline_module.go:136`, `:506`), printing none. The evidence is therefore three records that
  must agree; a missing record or any disagreement is `PreflightMismatch`:
  - **The compiled set, from the compiler.** Each assembly runs `ailang` from the assembled root with a fresh, empty
    `AILANG_CACHE_DIR=runs/<run-id>/cache` (non-empty at start → refused), `AILANG_NO_CACHE` unset (`=1` disables
    the cache, `cmd/ailang/main_run_exec.go:240`), and `-debug-compile` (`:239`). With the cache active the pipeline
    prints one `[CACHE] <module-id>: MISS` line per compiled module — or `SKIP` / `HIT but load failed` — and a
    `[CACHE] Summary: <h> hits, <m> misses (<k> modules cached)` line (`pipeline_module.go:267`, `:282`, `:287`,
    `:408`). A cache store that fails to open is skipped without a message and a failed save is ignored
    (`:215–220`, `:405`), so the runner requires: the summary line present; `h = 0`; no `SKIP` or `HIT` line; the
    `MISS` id set of size `m` and equal to the entries of `compile/manifest.json`, which must exist and parse
    (`internal/pipeline/cache_store.go:61–105`); both files recorded with SHA-256.
  - **The selected paths, from the runner.** The runner resolves every id in that set by the loader's own rules:
    project ids against the assembled root (`loader.go:320`); `std/` ids through the search paths the same run
    prints with `-trace-loader` (`[trace-loader] Search paths initialized`, then `Checking: <path>` per candidate,
    `internal/loader/stdlib_resolver.go:274`, `:187`) — the first candidate that exists is the selection — or the
    embedded copy when the trace shows the fallback (`loader.go:158–185`, `:177`; covered by the binary hash);
    `pkg/` ids through the **effective lock** below (`loader.go:145–157`; `internal/pkg/loader.go:44`, `:126–136`).
    Every selected file must exist and lie under the assembled root, the effective package root or the recorded
    stdlib root, or be the embedded copy; each is hashed.
  - **The import closure, from P1.4b.** The statement-level closure from the runner entry must equal the compiled
    set **minus** the entry prelude imports the loader injects (`loader.go:292`), which the record lists by name; a
    lexical import scan is never taken as the loaded set on its own.
  - **The residual gap**, printed in every verdict's envelope: a module's selected path is the runner's
    re-derivation of the loader's rules, cross-checked against the compiler's set, not the loader's own report. A
    loader flag printing id → selected path would close it; that is an AILANG feature request (raised through the
    `ailang-feedback` skill), not an assumption.
- **Packages: an evaluator-pinned, assembly-only effective lock.** A `path` package is used exactly as the lock
  writes it — absolute stays absolute, relative joins the project root (`internal/pkg/loader.go:126–136`). At
  `3920814`, `ailang.lock:71–77` pins `sunholo/motoko_ext_abi` to `/workspaces/motoko_agent/packages/motoko-ext-abi`,
  outside every assembled tree, so without a rule every run — admission, P, C and the control — would be refused
  at K0. The rule, applied identically to all of them:
  1. The entry pins, at A: `ailang.lock`'s SHA-256; each `path` package's tree hash from A's tree; each non-path
     package's resolved cache directory and tree hash.
  2. The runner copies each `path` package **from A's pinned tree** (never from C) to
     `runs/<run-id>/packages/<name>` and writes an **effective lock** into the assembled root that differs from A's
     lock **only** in those entries' `path` fields, rewritten to the copy's relative path; a JSON diff of the two
     locks showing any other change refuses.
  3. A candidate diff touching `ailang.lock`, `ailang.toml` or `packages/**` is `Refused(InadmissibleCandidate)`
     (v5 D3 and D5 confirm).
  4. The record holds the original and effective lock SHA-256, the rewrite diff, and each package's resolved real
     path and tree hash; K0 compares the effective lock and every resolved package file with the entry. C's and E's
     sources are unchanged; the effective lock exists only in the assembly.
- **K0** preflight: manifest, profile, toolchain and binary hash, corpus hashes, T0 settings, and all
  execution provenance equal what the runner assembled. **Commit:** `ADR-004 D3/D5: candidate assembly,
  refusals and execution provenance`.

### P1.9b — K1–K7 and the candidate verdict (1½–2 days, D3) — graph id `P1.9b-v2`

Deps `P1.9a`, `P1.7a`, `P1.7b`. K1 `world_state_of` and `reconstitution_balance`; K2
`strict_replay_findings(program.interactions, run.world.log)`; K3 `check_discovery(C.world.log, witness_C)`
with **`witness_C` built from C's own run** — `provider_calls` from C's trace's `ProviderCallPrepared` count,
`tool_dispatches` from C's initial minus final queue length, `clock_delta_ms` from C's worlds, the
source-derived `expected_env_reads` and route zeros from the entry — **then, separately,** C's three runtime
counts equal to the entry's (v5 D3 K3; the prepared-event digests are not consulted, the count is); K4
`evaluate` under `StrictAgainst(program.interactions)` with the entry's budgets and metadata, `family_evidence`
equal to the entry's record and the census recomputed from C's run equal to the entry's; K5 frames; K6 end
incl. the no-marker scan; K7 source transcript (P1.7a's A2 function) on C's trace against the entry.
**Comparands:** K1–K7 compare the candidate's run with the **entry** (its program, expectations and recorded
census), never with the admission run's derived manifest. Verdict `Reproduced { calls, end, envelope } |
Diverged { location: Location, finding: ReplayMismatch | ReconstitutionFinding | DiscoveryFinding | Violation
| CensusMismatch | FrameMismatch | EndMismatch | ChainMismatch } | Refused { InadmissibleCandidate |
EvaluatorTouched | ProtectedRegionTouched | PreflightMismatch | GuardTripped | ProgramUndecodable(ReplayRefusal) }`,
printed with the envelope every time; **any K failure forbids a score**, and the first K finding at its own
`Location` is the verdict's (K2's when K2 and K4's replay family both report); `regression_replay_findings` is
diagnostic only. The marker check reports *not applicable* for observation-preserving candidates, and the
verdict names what it rests on (the execution-provenance record). Tests: M14, M15's candidate rows, and C = P →
`Reproduced`. **Commit:** `ADR-004 D3: K1–K7 and the candidate verdict`. **v2:** supersedes v1.2's `P1.9b`
— K3's two-step comparison, K4's census comparand and the typed `Location` verdict were decided by v5 (§9).

### P1R → P1G

`P1R` (1 day, read-only; deps `P1.9b`; graph id `P1R-v2`): runs `make eval_matrix` and every P1 suite and
`make eval_protected_selftest`; checks `MATRIX.tsv` row by row against `MATRIX.expected.tsv` (observed equals
expected, positions pinned) **and its coverage of v5 D8's revised contract** clause by clause — per refusal
family a refused case and a clean twin, per cutoff a selector case, per A1–A9/A9b and K1–K7 a failing case and
its twin, one per `ReplayMismatch` variant, per seam arm, the witness under/over-count and prepared ≠ recorded,
per census row, the vacuous family — with every inapplicable M15 row carrying its recorded reason; the
**closure review** (v5 D5): the manifest's members against D5's starting set and the seams' actual
delegations, any missing member named; a **symbol inventory** of `src/eval/journal/` showing no second
comparison walk, reconstitution, persistence codec or manifest type (every call to the harness's
`strict_replay_findings`, `reconstitution_balance`, `load_program`, `ExecutionManifest` named with its call
site); red-first/mutation records present per §0.8. Output `REVIEW-plan004-p1-verdicts-codex.md` (or
`-claude-`, stated in the receipt). **On RETURN** it names the implicated parts and §0.10 (b) applies: their
prior `done` attempts stay, each gets a `sent_back` attempt, and `P1G` waits on their latest attempts. **v2:**
supersedes v1.2's `P1R` — the contract-coverage check and the closure review were added by v5 (§9).

`P1G` (operator; deps every P1 part and `P1R`; graph id `P1G`, unchanged): every P1 part's **latest** attempt
`done` and `P1R`'s **latest** verdict accepting (§0.10 (b)), the closure review included; `MATRIX.tsv` clean;
`make anchors`, `driver_leaf_inventory`, `strict_replay`, `event_vocabulary` green with no re-baseline; **E
pinned** — the commit and the `ailang` binary SHA-256 in §6, `../motoko_agent-eval` created at E after the
§0.5 collision check.

---

## 4. P2, P3 and after

### P2.1 — the memory guard (1 day)

Deps `PLAN1G`. `scripts/eval/mem_guard.py --peak-bytes <n> --peak-source <text> -- <command…>`. Defaults
(D8 leaves them to this plan; overridable in review):
- **Declared peak** required from every caller, in bytes, with its source.
- **Exclusive**: `flock` on `$EVAL_LOCK_PATH` (default `.motoko/eval-corpus/.heavy.lock`); a second heavy run
  is refused, not queued. **Self-tests set `EVAL_LOCK_PATH` and `EVAL_CGROUP_ROOT` to a scratch directory**.
- **Preflight** refuses if `memory.current ≥ 12 GiB`, or `current + peak + margin ≥ max` (margin 2 GiB), or
  `memory.max` is absent, malformed or zero; `max` = `max` (unlimited) is refused unless `EVAL_MEM_MAX_BYTES`
  is set to a positive finite integer (anything else is refused).
- **Monitor** every second; at `max − margin`, SIGTERM the process group, SIGKILL after 10 s, and wait until
  the group is reaped.
- **Record** `guard.json` written atomically (temp + rename) on **every** exit path — pass, refusal, trip,
  early child exit, monitor start failure: preflight values, samples, peak, trip flag, monitor gaps. Exit code
  distinguishes pass, refusal and trip; callers treat `trip: true`, a monitor gap or a missing record as
  **invalid**.

Tests (`scripts/eval/test_mem_guard.py`): each preflight refusal (threshold, headroom, absent, malformed,
zero, unlimited, bad override); a trip on synthetic growth with the process group reaped; lock contention; a
child that exits immediately still leaves a complete record; a clean exit with `trip: false`; a caller that
sees `trip: true` rejects the result. **Commit:** `ADR-004 D8 P2: the cgroup memory guard`.

### P2.2 — calibrate the verdict path on short segments (1½–2 days, heavy, record)

Deps `P1G`, `P2.1`, `QRET`, `SCAN0`. This calibrates **repeatability and the verdict path**, not the
regression (P3.2).
1. **Selector.** From the dev session `SCAN0` found scannable, the reader (P1.3) computes the maximal
   admissible prefix of N ≤ 100 calls whose every call is a continuation, with `end: CutoffBefore(<assistant
   entry of call N+1>)` so D1 yields `EndSuspended(N)`; and a second prefix of ≈ N/2 calls, computed and
   checked the same way (not assumed admissible because the longer one is). If no dev session yields a
   scan-clean admissible prefix of ≥ 20 calls: **stop and escalate**; do not relax the policy.
2. Admit both through the evaluator (scan, A1–A9, A9b) under the guard, with exposure rows.
3. **Measurement.** The profiling invocation recovered from the P0 archive (the one that produced
   `prefix_57.mprof`/`fix_57.mprof`) is adapted to the evaluator's `candidate` mode; §6 records the **exact
   argv**, the profiler and `ailang` binary identities, and the process scope (D4: entry load and hash checks,
   the seed fold **inside** the profiled AILANG process, program load, `world_state_of`, the run, K1–K7).
   Counts are pinned from the entry's expectations and **cross-checked against the journal and host-log
   receipts** (calls against `provider_call_prepared` events, appends against `history_appended` entries), so
   admission and measurement do not share one mistaken source.
4. Per segment: one warm-up (exposure row), then three repeats of P → `Reproduced` (allocation, GC, live heap,
   RSS, peak `memory.current`) and three of a known-divergent mutant → `Diverged` at the expected position,
   measurements discarded; every repeat is an exposure row.
5. §6: repeat deviation; a **proposed tolerance** with reasoning; observed peak (the declared peak for P3); the
   recommended gate length. Prototype numbers are not inputs.

### P3.1 — admit the finite dev entry (½–1 day, heavy, record)

Deps `P2.2`. The entry P2.2 recommends: full scan, A1–A9, A9b → `SourceFaithful`, under the guard.
**Criteria:** `SourceFaithful` receipt; `find` permissions check; identities and digests in §6; exposure log
complete (migrated rows + this run); a refused candidate recorded with its scan report, and the next scanned.

### P3.2 — the regression control (1½–2 days, heavy) — graph id `P3.2-v2`

Deps `P3.1`. **v5 D5/D8 make the same-basis control primary** and the historical route optional:
- **Same-basis (primary):** a candidate diff on A reverting `de4b4f5`'s change to `canonical_messages` in
  `phase_vocab.ail` (that commit touched only `src/core/phase_vocab.ail`, 10+/7−, and is an ancestor of
  `3920814`; v5 review §3.8). It is **not** admissible by construction; before its allocation result counts it
  must show: (i) reviewed as an admissible resource-only candidate under D3 — `canonical_messages` output
  byte-identical to A's on the digest fixtures and on the entry's seed; (ii) `tools/eval_protected check`
  passes at C (the **protected** basis equals A's; the assembled source identity differs and is recorded);
  (iii) K1–K7 pass on the entry; (iv) its allocation exceeds the budget.
- **Historical (optional; only by operator directive if the same-basis control does not fail (iv) after the
  escalation below):** `a6abda4` plus a reviewed compatibility patch with its own control-basis manifest
  enumerating every protected, schema and dependency difference (its `recording_ports` lacks the `wake_read`
  binding: definition-text SHA-256 `e6df6f20…` at `a6abda4:554–575` against `495d3c8f…` at `3920814:635–658`
  under the v4 review's span rule, C3), its own protected pins, type-checked, and equal entry observations with
  K1–K7 passing before any resource failure is credited (v5 D5 "The control basis").

**The threshold P3.2 uses is P2.2's proposed tolerance**, applied by the evaluator's `candidate` mode under the
guard to P and to the control in the same session, with the counts pinned from the entry: a **provisional**
comparison, recorded in §6 with both measurements. `make journal_replay_budget` does not exist until P3.3;
`P3G` proves the final target fails on the control.

**Pass condition:** K1–K7 pass **and** the provisional budget fails. A K0 or any refusal is not the rejection;
a control whose observations do not match is not a control (v5 D8 P3).
**Bounded escalation** if (iv) fails on the finite entry: **once**, within P3.2, admit one longer **dev or exposed**
entry of at most 150 recorded calls, under the guard with exclusive execution. It exceeds P2.2's ≤ 100-call
calibration, so it is **calibrated first**, inside P3.2, exactly as P2.2 steps 3–4 (profiling argv and scope recorded,
one warm-up, three repeats of P, counts cross-checked against the journal and host log, exposure rows) to obtain
**its own** peak, counts and proposed tolerance; only then are (iii)–(iv) run on it against **that** tolerance, and
`P3G` pins that entry's length and threshold. If the control still does not fail, stop and escalate to the operator
(the historical route, or a directive). P3.2 never depends on P5. **v2:** supersedes v1.2's `P3.2` — the control
class is decided: same-basis primary, historical optional (§9).

### P3.3 — `make journal_replay_budget` (1 day) — graph id `P3.3-v2`

Deps `P3.2`. Runs a named tree (default P) on the entry **through `mem_guard.py`** for parent, control and
candidate alike; pins allocation with P2.2's tolerance and exact counts — calls, appended messages, tool
invocations, interactions by class, env reads by key, **decisions** (v5 D8 P3) — from the entry; fails closed
on a loader error, missing profile, preflight or provenance mismatch, divergence, changed measurement scope,
guard trip or missing guard record. Pins live in an evaluator path; a repin requires a recorded reason **and
an operator directive** (a changed pin is a basis change, D5). Not in `DST_TARGETS`/`make dst` (heavy,
exclusive — stated in the target's comment). Tests: each fail-closed arm on the synthetic entry. **Commit:**
`ADR-004 D8 P3: journal_replay_budget, pinned`. **v2:** supersedes v1.2's `P3.3` — the decision count joined
the pinned counts (§9).

### P3G — the gate (operator)

Deps `P3.1`, `P3.2`, `P3.3`. Criteria, each with a command receipt (command, exit, measured value) in §6:
final evaluator on the finite entry (or P3.2's escalation entry, named) — A1–A9 and A9b pass; K0–K7 pass for
P; the control passes K1–K7; **`make journal_replay_budget` exits 0 on P and non-zero on the control, by the
allocation budget**; the budget and segment length pinned. ADR-004's Consequences gain a "measured" line citing
these finite-entry results, not prototype values.

### P4 — the held-out process (operator)

Deps `P3G`. **Criteria:** a written process (outside the repo) defining exposure classes — `dev`, `exposed`,
`held-out` — and who may reclassify; collection authority (the operator); held-out storage outside the
repository and every candidate's write scope (default `~/.motoko-heldout/`, 0700) with its own pins and
results; per-entry outcome reporting including refusals; and a statement that no held-out identity or result
reaches Motoko or any candidate-producing agent. Settled by an operator directive.

### P5 — long admission (1–3 days, heavy)

Deps `P3G`. **Dev or exposed entries only** when run through Motoko; a held-out long entry is the operator's,
outside this run. A 300-call-class entry, only under the guard with exclusive execution, never inside a sweep;
declared peak from P2.2 scaled with its reasoning (the 6,969–7,058 MiB RSS of the 300-call replay with
`de4b4f5` is a **terminal-augmented prototype** figure, scale only). **Criteria:** `SourceFaithful` or a named
refusal; guard record valid; exposure rows; §6 record. A trip is a result, not a retry loop.

### P6 — T1

**Canceled from this run.** T1 needs its own ADR revision or plan (ADR-004 D7).

---

## 5. Owner questions and v1.2's v5 markers — all answered

| id (v1.2) | question | answered by | applied in |
|---|---|---|---|
| `QRET` | Retention: duration, supersession handling, deletion rule, covered paths | operator, `QRET·a1` 2026-09-15: §0.11's default adopted | §0.11, §6 |
| v5 D8 | "one known-divergent and one known-refused case per refusal family" | v5 D8 revised the sentence per vocabulary; `V5G` ruled the near-misses satisfy the per-check requirement and the inapplicable rows stand as reasoned | M15, P1R |
| v5 1 | Zero-call `tool_calls`, blank completion, hybrid predicate, `StopBeforeEnd` | v5 D1: cut (`CallFreeToolCallsFinish`), cut (`BlankStop`, reachable), asserted once at admission (`HybridPredicate` refusal), the one post-turn cutoff | M3, M4, P1.3 |
| v5 2 | Env values, profile path choice, context-limit encoding, fault-path counts | v5 D1's settings table (both keys `""`, explicit `MOTOKO_PROFILE_DIR`, `FsFile` config, `n > 0` / `"disabled"`); D3's three-column env table | M5, P1.3, P1.5, P1.7b |
| v5 3 | Candidate witness comparison | v5 D3 K3: `witness_C` from C's trace/queues/worlds, then the three counts against the entry | P1.9b |
| v5 4 | `ReplayObligation`, metadata, budgets, census | v5 D3: `NoReplay` / `StrictAgainst`, `replay_metadata_of(manifest)`, `decision_budget` = `2N + 1` / `2N`, `retry_budget` 0, thirteen-row census | M11, P1.7b |
| v5 5 | Failure `TimedOutcome` fields, marker handling, finding locations, manifest provenance | v5 D2: the harness's exhausted record and the `ToolFailed` arm mirror (C2); first mismatch, never a universal `ProgramExhausted`; D3 typed `Location`; A9b over P1.6's table | M8, M14, P1.5, P1.6, P1.7a |
| v5 6 | Protected closure, comment rule, execution/cache/package provenance | v5 D5: the closure from a reviewed starting set (C5), original-byte spans with the literal-aware lexer (C6), P1.9a's provenance contract adopted | P1.4b, P1.9a |
| v5 7 | Control class and basis | v5 D5/D8: same-basis revert of `de4b4f5` primary; historical `a6abda4` optional with its own manifest | P3.2 |
| v5 8 | Scan policy text, `CredentialBearingName` | v5 D6: body-16 over every occurrence of the 23 prefixes as a stated heuristic; `CredentialBearingName` report-only by explicit rule; r2.1 refused at its seed | P1.8, SCAN0 |
| v5 — | Park/wake refusal reason; decoders as copies or imports | v5 D1: `Parked` is a cutoff, a wake-opened run `ContinuationStart`, a stray wake `MalformedEntry`; D5: copies pinned by span hash | M1–M3, P1.2a |
| §0.5, §4 P2.1 | Evaluator paths, E worktree, guard defaults | as stated; P2.1 landed with margin 2 GiB, poll 1 s (`55f1100`) | overridable in `PREV` |

No open owner question remains at v2. New questions go to the operator through the graph (`kind: question`).

## 6. Results

### `PSYNC`, 2026-09-16: PLAN-004 v2 and the v2 graph

HEAD `988a863`. `git diff 3920814 988a863 --stat -- src/ scripts/dst/ Makefile tools/` → empty (code
coordinates unaffected; HEAD adds docs and `scripts/eval/`). a grep for v1.2's marker string on this file → 0 outside §9's
history. `dagr check .dagr/run-plan004-v2.json --strict --json` → `[]`, exit 0 (dagr 0.3.1); the same on the
copy in `evidence/plan004-v2/`. The graph: run `run-plan004-v02`, 40 tasks (v1.2's set; nine under new ids, §9),
9 terminal tasks with one summary attempt each, `PSYNC` in `review` with `PSYNC·a1` queued, 29 queued, `P6`
canceled, one `note` event, a top-level `supersedes` object. Not run: `make dst` (heavy; `SWEEP` was in
progress), any replay.

### `QRET`, 2026-09-15T20:00:11Z: the retention ruling (operator, `QRET·a1`, `run-plan004-v01`)

Directive `verb: answer`: "adopt §0.11 default — retain until 90 days after P3G or ADR-004 supersession,
whichever first; on supersession delete by default or migrate under reviewed re-admission; deletion removes
every copy, recorded in §6, leaving counts/digests/identities." Covered paths as §0.11 lists them. Applied in
§0.11.

### §0.10, 2026-09-15: the RETURN transaction on synthetic documents

Scratch documents (no corpus content) under
`/tmp/claude-1001/-workspaces-motoko-agent/d8b1d53b-1a2d-4c49-b4ec-fc412754e86a/scratchpad/dagr-round/`, dagr
0.3.1, each through `dagr check <f> --strict --json` and `dagr view <f> --snapshot --width 140`:

| document | shape | check | rendered |
|---|---|---|---|
| `S1_under_review` | author task `review`, attempt `working`; review `working`; gate deps author + review; policy on the author | exit 0, `[]` | author `review`; futures `pass ⇒ gate`, `⟲ A·a2`, `≈ G·ask`; gate `waits A` |
| `S1b_under_review_queued_attempt` | as S1 with the author attempt `queued` | exit 0, `[]` | futures not drawn (they render only for working/blocked); gate `waits A` |
| `S2_return_sent_back` | review `done` (receipt RETURN); author a1 `rejected`; a2 `working` `sent_back` ref review a1; policy forecasts `A·a3` | exit 0, `[]` | author `sent back`, `↩ A·a2 working`; gate `waits A` |
| `S2x_collision` | as S2 but the policy still forecasts `A·a2` | exit 1, `E164` | — |
| `S3_rereview` | author `review` with a2; review a2 `working` `followup` ref author a2 | exit 0, `[]` | review `R·a2 working`; gate `waits A` |
| `S4_accept_gate_ready` | review a2 `done` ACCEPT; author a2 `done` | exit 0, `[]` | gate `ready` |

*(Each task appends its record here, newest first: date, HEAD, commands, exit codes and output excerpts, what
could not run.)*

## 7. Estimates

| project | delegate-days | why |
|---|---|---|
| P0 | 1½ | preserve ½, sweep ½ (wall time uncertain), scan ½; ≈1 elapsed in parallel |
| PLAN | ½–1 | done: v1.2's review round and the operator gate |
| ADR | 4–6 | V5 2–3, V5R ½–1, V5G: done; PSYNC 1 (this document); PREV ½–1 remaining |
| P1 | 18½–22 | P1.1 ½, P1.1R ½, P1.2a 1, P1.2b 1, P1.3 1½, P1.4a 1, P1.4b 1½–2, P1.5 1½–2, P1.6 2–2½, P1.7a 1½, P1.7b 1½–2, P1.8 1–1½, P1.9a 1½–2, P1.9b 1½–2, P1R 1 |
| P2 | 2½–3 | guard 1; calibration 1½–2 |
| P3 | 3–4 | admission ½–1; control 1½–2 (its one calibrated escalation adds up to 1); target 1 |
| **to P3G** | **30–37½** (38½ with P3.2's escalation) | P4 operator; P5 1–3 after |

---

## 8. Starting Motoko on this plan

**Two files, two authorities.** The herdr extension's producer writes **its own** run file
(`.dagr/run-<pane>-<session>.json`) and **reads** the `dagr_plan` file, never writing it
(`DESIGN-dagr-as-delegation-view.md` §10.5; `packages/motoko-ext-herdr/dagr.ail:272`). On first read it seeds
each plan task it does not already have — state, deps, owner, criteria, note, project; a terminal task arrives
with one `operator`/`reported` attempt, and **no** attempts, events or policy are copied — and **never
updates a task it already has** (`seed_tasks`, `dagr.ail:252–263`; `plan_task_of`, `:215–246`). Therefore:

| file | writer | authoritative for |
|---|---|---|
| operator plan graph (`run-plan004-v2.json`; `run-plan004.json` is v01, the record through `PLAN2G`) | one writer at a time: the running Motoko session (settlements only) or, between sessions, the operator's planning session (structure) | operator decisions, gates, directives, review verdicts, settlements and their receipts |
| producer run file | the extension only | observed delegate attempts: panes, liveness, delegate answers, lost/failed runtime outcomes |

- **Settlements only while a session runs.** The Motoko session may append attempts and events, set states,
  and edit `policy` exactly as §0.10 prescribes, through `.tmp` → `dagr check --strict --json` → `mv`. It never
  adds, removes or renames tasks and never changes `deps`, `criteria` or projects. Those settlements do not
  reach the producer's already-seeded run file, by design.
- **The two-file receipt.** Before each delegation and at each gate, the session appends a `note` event to the
  plan graph whose `detail` is `receipt task=<id> producer_run=<run file path> producer_state=<state>/<latest
  attempt id> plan_state=<state>/<latest attempt id> evidence=<review doc sha256 | commit | §6 record>`. **Before
  the first `Delegate`** no producer run file exists: that one receipt reads `producer_run=absent
  producer_state=absent`; the first reply must show `dagr_task` linked; and the **next** receipt, before any
  further delegation or gate, must name the real producer run file. A state difference is expected (seeding is
  one-shot). An **evidence** difference — the producer shows the task's delegate `lost` or `failed` while the plan
  says `done`, or a receipt names a commit git does not have — **blocks the gate** until the operator records a
  ruling as a `directive` event, which the gate's receipt names. `dagr check` validates none of this (a note's
  `detail` is free text); the gate criteria enforce it.
- **Structure changes between sessions**, by the operator's planning session, in a **new plan file** with
  changed parts under new ids (as `PSYNC` does). **A fresh Motoko session per plan file is an operator rule, not
  a code invariant**: the extension would accept a second `dagr_plan` declaration in the same session and
  overwrite its per-session marker (`herdr.ail:585–599`; `dagr.ail:395–397`). So the prompt forbids
  redeclaring, and the operator verifies, for the new session: `.dagr/.plan-<pane>-<session>` names the intended
  plan file; the first `Delegate` reply shows `dagr_task` linked; the producer run file contains the plan's task
  ids (an unreadable plan seeds nothing, `dagr.ail:269–284`, so a strict-clean plan file alone proves nothing).

The fresh session's pane is the operator's choice; the planning session sets `run.orchestrator.pane` in the v2
file before the start (the file carries v01's `w1:p18` until then). Start only after the running session's
`PLAN2G` handoff. The prompt:

```
Implement PLAN-004 v2 (.agent/projects/013_core_architecture_for_dst/PLAN-004-implement-adr-004.md)
from the operator plan graph .dagr/run-plan004-v2.json. ADR-004 v5 is Accepted.
Pass `dagr_plan: ".dagr/run-plan004-v2.json"` on your first Delegate call and
`dagr_task` with the graph task id on every one (renamed parts end in -v2:
P1.2a-v2, P1.2b-v2, P1.3-v2, P1.7a-v2, P1.7b-v2, P1.9b-v2, P1R-v2, P3.2-v2,
P3.3-v2). Never declare a different dagr_plan in this session.

After your first Delegate, CHECK THE RESULT TEXT. If it says the plan was not
recorded, a plan in effect could not be read, or `dagr_task` was not linked,
stop and report it.

THE PLAN GRAPH (§8)
- You are its only writer while you run. SETTLE only: append attempts/events,
  set states, and edit `policy` exactly as §0.10 says — via a .tmp copy,
  `dagr check --strict --json` → [], then `mv`. Never add, remove or rename
  tasks, never change deps, criteria or projects. A structural need: stop and
  write a handoff.
- Before each delegation and at each gate, append the two-file receipt note
  (§8; producer_run=absent only before your first Delegate). An evidence
  mismatch blocks the gate until the operator rules by directive.
- The terminal tasks carry one summary attempt each; their history is in
  .dagr/run-plan004.json (v01). Do not re-open them.

WHERE TO CONTINUE — work it out, do not assume
- `git log --oneline` is authoritative for what landed (§0.7). Reconcile first:
  SWEEP, PRESERVE and SCAN0 may have finished in the v01 session (their §6
  records); PSYNC and PREV are settled in v01 — mirror each as one summary
  attempt here from v01's receipt before anything depends on them.
- PLAN2G is settled HERE by the operator, on the fresh-session receipt (§2):
  your first Delegate goes to a task outside PLAN2G (SWEEP, PRESERVE, SCAN0,
  P1.1 after SWEEP), then ask the operator to settle PLAN2G. Everything else
  in P1 waits for it, by design.
- QRET is answered (§0.11). Say which task you picked and why before delegating.

REVIEWS (§0.10) — the transaction, exactly
- Artifact reviews (P1.1R): author done → author task state `review`, attempt
  stays open. OPEN THE REVIEW YOURSELF — its row shows "waits <author>" by
  design. From round 2: followup ref the author attempt.
- Verdict → review attempt `done` (receipt: doc path, sha256, verdict). Same
  document: ACCEPT → author attempt `done`; RETURN → author attempt `rejected`
  + new author attempt `sent_back` ref the review attempt, and the author
  policy's fail future moved from ·aN to ·aN+1.
- Third RETURN → author task `blocked`. A fourth round only in the same
  mutation as the operator's unblock directive, removing the ·ask future and
  setting rounds_max to what the directive authorises. dagr will not stop
  you; this rule does. A directive never turns a RETURN into acceptance.
- P1 parts settle `done` on their own receipts. A P1R-v2 RETURN keeps each
  implicated part's done attempt and appends a sent_back attempt; P1R-v2 is
  re-reviewed when those parts are done again.
- PLAN2G, P1G, P3G are the operator's; P1.1G you check yourself.

HOW TO WORK
- impl/docs/test parts: `kind: claude`. Reviews (P1.1R, P1R-v2): Codex
  `gpt-5.6-sol` if Delegate offers it, else claude, and say so (the review
  file is then named -claude-, as V5R's was).
- Before each brief read that part's section IN FULL plus §0, the ADR-004 v5
  decisions it names, and the git log of prior parts. The plan is grounded at
  3920814 (unchanged for code at 988a863); tell delegates to resolve stale
  line numbers by reading the code.
- §0.6 privacy binds briefs: no corpus content anywhere — counts, digests,
  indices, identities only.
- Each code delegate makes exactly ONE commit and does not push; §0.7 lists the
  exceptions. You verify the gate yourself. A gate that could not run is not a
  gate that passed.

CONCURRENCY AND MEMORY (§0.2)
- At most two delegations in flight; at most ONE heavy task (SWEEP, P2.2, P3.1,
  P3.2-v2, P3.3-v2, P5, or any make dst). memory.current < 12 GiB before
  starting one; every real-segment run goes through scripts/eval/mem_guard.py.
- Suggested opening: P1.1 (after SWEEP) + P1.4a and P1.4b once PLAN2G is
  settled; P1.2a-v2 next; the P1.5 fan-in waits for P1.1G and P1.3-v2.

BUDGET
- 1200 steps; each DelegateCheck costs one and blocks 45 s. At ~1000 stop
  starting tasks, collect in-flight work, settle the graph, and write a handoff
  naming the last commit, in-flight handles and next task ids.
```

---

## 9. What changed, by version

**v1.2 → v2** (`PSYNC`, 2026-09-16, against ADR-004 v5 at `988a863`, `V5G` accepted). Every v1.2 marker
"⟨v5⟩" — thirty lines: the header, §0.9's park row, §2 `V5` and `PSYNC`, M1 and M15's park row, P1.2a, P1.3
(two), P1.4b, P1.5 (two), P1.6's `abi_version` row, P1.7a, P1.7b, P1.8, P1.9a, P1.9b, P3.2, and §5's heading
and ten rows — is replaced by the decision v5 names for it (§5's table gives the mapping). Deltas, part by part:

1. *D1 — park/wake and the stopping contract.* M1's park/wake row moved to M3 as the `Parked` cutoff (cut
   before the call-free stop-class call k preceding the park, `EndSuspended(k−1)`, C1); M1 gained the
   stray-`wake` `MalformedEntry` case and M2 the wake-opened `ContinuationStart` case; M3 gained `Parked`,
   `CallFreeToolCallsFinish`, `BlankStop`, `HybridExtraction`; M4 is the six-shape procedure with the
   `HybridPredicate` refusal; M5 pins the explicit profile directory, the `FsFile`, both empty keys and the
   context-limit encoding; `expected.decisions` = `2N + 1` / `2N`. §0.9's park row is marked withdrawn.
2. *D2 — decoders and seams.* Copies, not imports, pinned by span hash (P1.2a). The seams' empty arms write
   v5's exact records; k is the seam's own `ProviderIdentity` count (C2); `{ base | … }`; structurally equal
   prefix; the world's env and file table as D2 builds them (P1.5: values pinned, contract unchanged).
3. *D3 — locations, witness, bridge, census.* Typed `Location` with four variants and `AdmissionCheck(Ak,
   A9b, location)` (P1.7a); the three-column env table, `NoReplay`, `replay_metadata_of(manifest)`, the
   derived decision budget, retry 0 and the thirteen-row census asserted (M11, P1.7b); K3 from C's own run
   then the three counts, K4's census comparand, the typed verdict (P1.9b).
4. *D5 — closure and control.* P1.4b's symbol list is v5 D5's reviewed starting set incl. the v5 review
   §3.8 transitive names (C5); the lexer rule (C6) was already P1.4b's; A9b adopts P1.6's table and D5
   adopts P1.9a's provenance contract by reference; the same-basis revert of `de4b4f5` is the primary
   control, `a6abda4` optional by directive with its own manifest (P3.2); the decision count joins P3.3's
   pinned counts.
5. *D8 — the test contract.* v4's per-family sentence is revised by vocabulary; M15's near-misses are the
   per-check known-failing cases, its inapplicable rows satisfied by their recorded reasons (`V5G`); the park
   row is inapplicable, a `HybridPredicate` row is added as inapplicable, the `ProtectedRegionTouched` row is
   a closure regression test; P1R checks coverage of the revised contract and reviews the closure (P1R;
   P1G's "closure review included").
6. *Status and history.* `QRET` ruled (§0.11, §6); `PLAN1G`, `V5`, `V5R`, `V5G`, `P2.1` done; ADR-004 v5
   Accepted (status line flipped in this commit); §0.5 notes the guard at HEAD; §0.7 counts `V5`'s three
   commits; §0.9 corrected (`tool_outcome_record :2133`, C4's module list, the park row); §8's prompt is the
   fresh session's; §5 closed.

**The v2 graph** (`.dagr/run-plan004-v2.json`, run `run-plan004-v02`; copy in `evidence/plan004-v2/`),
written from v1.2's structure, not by editing it. **Id rule applied:** a part got a new id when v5 changed
what it must build or test (a case added or moved, a type, comparator or route decided differently from
v1.2's proposal); it kept its id when v5 confirmed v1.2's proposal and only values, coordinates or the
marker changed. A dependency on a *renamed* predecessor is the same predecessor and is not a deps change.
The map (v2 id ← v1.2 id), also in the file's top-level `supersedes` object, its opening `note` event and each
renamed task's `note` and `supersedes` field:

| v2 id | supersedes | why |
|---|---|---|
| `P1.2a-v2` | `P1.2a` | park/wake row left M1; stray-wake case; copies not imports |
| `P1.2b-v2` | `P1.2b` | wake-opened `ContinuationStart` case |
| `P1.3-v2` | `P1.3` | six-shape procedure; four cutoffs and one refusal added; settings values; decision count |
| `P1.7a-v2` | `P1.7a` | four-variant `Location`; `AdmissionCheck` with A9b and location |
| `P1.7b-v2` | `P1.7b` | obligation, metadata, budgets, decision-count assertion, thirteen census rows |
| `P1.9b-v2` | `P1.9b` | K3 two-step comparison; K4 census comparand; typed verdict |
| `P1R-v2` | `P1R` | coverage of the revised D8 contract; closure review |
| `P3.2-v2` | `P3.2` | same-basis control primary; historical optional by directive |
| `P3.3-v2` | `P3.3` | decisions among the pinned counts |

Unchanged ids: `QRET`, `PRESERVE`, `SWEEP`, `SCAN0`, `PLANW`, `REV1`, `REV2`, `PLAN1G`, `V5`, `V5R`,
`V5G`, `PSYNC`, `PREV`, `PLAN2G`, `P1.1`, `P1.1R`, `P1.1G`, `P1.4a`, `P1.4b`, `P1.5`, `P1.6`, `P1.8`,
`P1.9a`, `P1G`, `P2.1`, `P2.2`, `P3.1`, `P3G`, `P4`, `P5`, `P6` (canceled). Terminal tasks (`QRET`,
`PLANW`, `REV1`, `REV2`, `PLAN1G`, `V5`, `V5R`, `V5G`, `P2.1`) carry one summary attempt `<task>·a1`
(`reported`, receipt naming the v01 attempts and their evidence); `PSYNC` is in `review` with `PSYNC·a1`
queued; no v01 attempt, event or policy is copied; author policies stay on `PSYNC` and `P1.1`. Deps that
named a renamed part name its v2 id (`P1.5` ← `P1.3-v2`; `P1.9b-v2` ← `P1.7a-v2`, `P1.7b-v2`; `P1R-v2` ←
`P1.9b-v2`; `P1G` ← every P1 part; `P3.3-v2` ← `P3.2-v2`; `P3G` ← `P3.2-v2`, `P3.3-v2`).

**v1.2's six corrections** (`REVIEW-plan004-v1.2-delta-verdicts-codex.md`, ACCEPT WITH CORRECTIONS, "Verdict for
PLAN1G" items 1–6), applied before `PLAN1G`:

1. *Review flow.* §0.10 split into (a) artifact reviews — the orchestrator opens a review by hand while its author
   is in `review`; a fourth round only in the same mutation as the unblock directive, removing the `·ask` future
   and resetting `rounds_max` — and (b) the aggregate `P1R`: parts settle `done` on their own receipts, a RETURN
   appends `sent_back` attempts to implicated parts without rewriting their `done` attempts. §8's prompt matches.
2. *First receipt.* `producer_run`/`producer_state`/`plan_state` labels; `producer_run=absent` only before the first
   `Delegate`, then linkage and a real receipt; mismatches ruled by a directive the gate names.
3. *M15.* Provisional until `V5G` rules; the wrong-run `Association` and edited-program cases replaced; A3 cases
   conditioned on a next evaluated call; each inapplicable row justified separately; every near-miss asserts its
   own family's refusal and earlier checks pass. `MATRIX.expected.tsv` freezes expected verdict, first finding and
   position; `MATRIX.tsv` holds only observed values.
4. *Checker and identities.* One aggregate import span per contiguous run (no nesting), `as` aliases, trailing
   `deriving`, a parser cross-check for non-braced types, coordinates corrected (`stub_step.ail:44`,
   `ports.ail:60–67`). P1.6: `python3 tools/ext_call_inventory/derive.py --json`; the classifier claim narrowed to
   agreement with the reviewed record in `profile_definition_dst.ail`; scan roots compared like for like; profile
   and rule versions narrowed to consistency; the lock's `interface_hash` recorded, not treated as a version.
5. *Loader evidence.* P1.9a: the cache must be demonstrably active (no `AILANG_NO_CACHE`, `-debug-compile`
   summary with zero hits), a missing or failed manifest refuses, selected file paths come from the runner's own
   resolution checked against the cache's module set and the stdlib search trace, and an evaluator-pinned,
   assembly-only effective lock replaces `ailang.lock`'s absolute package path so P can run. The executing source
   is the installed `/home/motoko/.local/share/ailang` at `ae36986`, not the repo's `ailang/` (`de5a141`).
6. *P3.2 and notes.* The ≤ 150-call escalation is calibrated inside P3.2 before its rejection counts; conditional
   maximum 38½; §1's author→review arrows annotated as submission order; the aggregate-review exception stated.


**v1.1 → v1.2**, the five required changes of `REVIEW-plan004-v1.1-delta-verdicts-codex.md`:

1. *Append-only RETURN transaction.* §0.10 rewritten and tested (§6): author tasks carry policies and stay
   unsettled under review; gates depend on author and review; RETURN = `rejected` + `sent_back` + policy future
   moved `·aN`→`·aN+1` in one document; third RETURN → `blocked` + directive; no directive bypass; `P1R` routes
   RETURNs to implicated parts. New author task `PLANW` (retroactive a1, a2) with `REV2·a2` as its reviewer;
   policies removed from review tasks; `PLAN1G`'s directive alternative withdrawn; `PSYNC` depends on `PLAN1G`
   directly.
2. *Two files, two authorities.* §8's authority table and two-file receipt; history carried in the operator
   graph only; the fresh session stated as an operator rule, with the marker, linkage and producer-file checks
   as `PLAN2G`'s receipt.
3. *D8's literal reading.* M15 maps a known-divergent near-miss (or an inapplicable ruling) to every refusal
   family; V5 must confirm or revise D8's sentence; `MATRIX.tsv` records observed verdicts and positions;
   `gen_fixtures.py` and the snapshot's recorded digests are A1's independent expectations.
4. *Provenance.* P1.4b parses import **statements** and an import region, non-braced multi-line types, and
   decides at C (missing, duplicate, moved); P1.6's table checks every identity against a different source
   (`ailang.toml` vs `ailang.lock`; `ext_call_inventory` vs `check_fixtures.derive`; `derive.py SCAN_FILES`; git
   object checks; E's pinned binary hash); P1.9a uses a fresh `AILANG_CACHE_DIR` per assembly and its
   `compile/manifest.json` module set as the loader's evidence, pins `std/` (filesystem or embedded) and `pkg/`
   roots, and catches `ailang.lock`'s absolute package path pointing outside the assembled tree.
5. *P3.2 and arithmetic.* P3.2 uses P2.2's proposed tolerance as a provisional budget in the same session, P3G
   proves the final target; one bounded escalation to a ≤150-call dev/exposed entry inside P3.2, never P5; P1
   18½–22 and to P3G 30–37½; `ailang.lock` must be committed before a clean-tree admission.

**v1 → v1.1**, the eight required changes of `REVIEW-plan004-v1-verdicts-codex.md`: provisional early work
stated; review→gate pairs and rounds; §8 grounded in the extension's seeding code with a new graph file for
v2; retention default and `QRET` before any copy, exposure migration, P4/P5 criteria; the M1–M14 case→test
table and the red-first/mutation rule; P1.2/P1.4/P1.7/P1.9 split with concrete contracts; P3.2's two routes
and four obligations; estimates, commit exceptions, citations, P6 canceled, owners as executing kinds.

## Cross-references

- ADR-004 v5 (Accepted, `988a863`) and its reviews: `REVIEW-adr004-v5-verdicts-claude.md` (ACCEPT WITH
  CORRECTIONS; §1, §2, §3.1–3.12, §4, "Required changes for v6": none; C1–C6), `BRIEF-adr004-v5-review.md`;
  `REVIEW-adr004-v4-verdicts-codex.md` (the return of v4; §2, §3.1, §3.3–3.11, "Required changes for v5"),
  `-v3-`, `-v2-` (Codex, Fable), `REVIEW-adr004-verdicts-codex.md`.
- This plan's reviews: `REVIEW-plan004-v1-verdicts-codex.md` (v1, RETURN), `REVIEW-plan004-v1.1-delta-verdicts-
  codex.md` (v1.1, RETURN); briefs `BRIEF-plan004-v1-review.md`, `BRIEF-plan004-v1.1-review.md`,
  `BRIEF-plan004-v1.2-review.md`; `REVIEW-plan004-v1.2-delta-verdicts-codex.md` (v1.2, ACCEPT WITH CORRECTIONS);
  `REVIEW-plan004-v2-verdicts-*.md` (`PREV`, pending).
- dagr: `dagr --skill` (append-only attempts/events, send-back, policy materialisation);
  `.claude/skills/dagr-producer/examples/03-send-back.json`, `05a-`/`05b-policy-*.json`.
- PLAN-003 (§0, P4 layout, §5 records) and `.dagr/run-plan003.json`;
  `HANDOFF-2026-09-12-plan003-p1-and-the-delegation-view.md` §6.
- `021_herdr_delegation/DESIGN-dagr-as-delegation-view.md` §10.2, §10.5–10.6;
  `packages/motoko-ext-herdr/dagr.ail:215–335`, `:395–397`; `packages/motoko-ext-herdr/herdr.ail:585–599`.
- AILANG v0.33.0 (`ae36986`) — the **installed** source at `/home/motoko/.local/share/ailang` (the repo's `ailang/` checkout is `de5a141` and is not the executing source): `internal/pipeline/cache_store.go:61–105`; `internal/pipeline/pipeline_module.go:136`, `:215–220`, `:267–287`, `:405–408`, `:506`; `internal/loader/loader.go:145–185`, `:292`, `:320`, `:468–475`;
  `internal/loader/stdlib_resolver.go:187`, `:274`; `internal/pkg/loader.go:44`, `:126–136`; `cmd/ailang/main_run_exec.go:239–240`; `ailang.lock:71–77`; `packages/motoko-ext-abi/ailang.toml:1–3`; `tools/ext_call_inventory/derive.py:480`; `scripts/dst/profile_definition_dst.ail`;
  `tools/profile_definition/check_fixtures.py:25`, `:35–37`; `Makefile:3080–3082`.
- `HANDOFF-2026-09-13-plan001-p2d-sweep-pending.md` (the 12 GiB rule; `de4b4f5`).
- ADR-001 D2, D6; ADR-003 D2, D4, D7; PLAN-003 §0.6.
- Code at `3920814`: `stub_step.ail:28–44`, `:69`, `:203`, `:478`, `:635`; `ports.ail:60–81`, `:1723`, `:1827`,
  `:2056`, `:2133`, `:2507`, `:2522`, `:2577`; `session.ail:195`, `:272`, `:1532–1545`, `:2760`, `:3255`, `:4423`;
  `journal.ail:1253–1256`; `ledger_parity_dst.ail:73`, `:428–435`; `dst_profile.ail:1535–1573`;
  `dst_driver_only.ail:1097–1123`; `strict_replay_dst.ail:631–633`; `anchors.sh:593`, `:614–617`;
  `derive.py:154`; `Makefile:350`, `:697`, `:1099`, `:1516`, `:3071`, `:3095`.
