# AILANG `mission-control` skill — SKILL.md, gates 0–2, and four reference files

Source: sparse clone of `sunholo-data/ailang` `dev` at `2a1f3f295` (2026-10-03), read-only.
All paths below are relative to `.claude/skills/mission-control/` unless they start with another
directory. Resource files live in `resources/`; I cite them by bare filename.

Convention in these notes:

- **OBS** = read directly in the text, or measured by me with a command on the checkout.
- **INF** = my inference. Kept in its own paragraphs or tagged inline.
- Every incident, date and number is **as the skill text records it**. I did not check any of them
  against the mission logs.

## 0. What was read

Read in full, every line:

| File | Lines | Bytes |
|---|---|---|
| `SKILL.md` | 620 | 53,986 |
| `gate-0-preflight.md` | 240 | 21,648 |
| `gate-1-observe.md` | 278 | 22,402 |
| `gate-2-pick.md` | 585 | 51,048 |
| `ci-health.md` | 121 | 9,059 |
| `codex-lane-false-greens.md` | 158 | 13,312 |
| `ref-drift.md` | 68 | 3,884 |
| `role-spawn-routing.md` | 102 | 7,042 |

Also read in full, outside the assignment, because question 6 turns on them:
`.claude/rules/context-docs.md` (91 lines) and `scripts/check_context_docs.sh` (241 lines).

Excerpts only (the other agent owns these files): `gate-3-route.md` lines 3–30, 52–66, 236–252
(roles table and the generator/judge rule, needed for question 4); `gate-5-retro.md` lines 1–24
(the skill-edit rule, needed for question 6); `scripts/context_docs_baseline.txt` lines 1–25.

Section 10 lists what was not read.

---

## 1. Gates 0, 1 and 2

Shape common to all three (OBS). `SKILL.md` holds a stub per gate of nine lines: a heading, a
one-line summary, and an instruction to read the resource file. The stub text is identical across
gates except for the name:

> "**⚠ THE FULL RULES FOR THIS GATE ARE NOT IN THIS FILE.** Read `.claude/skills/mission-control/resources/gate-0-preflight.md` **NOW**, before doing anything in Gate 0. It is the authoritative text; this stub is an index entry, not a summary you may act on. Skipping the read is how a gate's rules silently stop applying." (`SKILL.md:239-242`)

Gates "run in order and are not skippable; earlier gates are cheap and prevent expensive mistakes"
(`SKILL.md:9-10`). Each gate's first action is a heartbeat stamp:
`bash tools/launchd/mission-heartbeat.sh stamp gate-N` (`gate-0-preflight.md:3`,
`gate-1-observe.md:3`, `gate-2-pick.md:89`). `SKILL.md:338-339` calls those stamps "the durable
attribution contract" for a slot that dies silently.

### Gate 0 — PREFLIGHT (`gate-0-preflight.md`, 240 lines)

Heading: "deterministic; abort = exit silently with a controlplane message" (`:1`).

Procedure, seven numbered steps (OBS):

1. **Kill switch** set → STOP, "no message needed; this is the intended off state" (`:6`).
2. **gh identity**: `gh auth status` must show `sunholo-voight-kampff` before any push; wrong
   account → `gh auth switch --user sunholo-voight-kampff` "or park all push steps" (`:7-8`).
3. **Dirty main checkout** → "do NOT stash/checkout (Critical Principle 0)"; doc-only edits may
   proceed; sprint work goes to a coordinator worktree (`:9-10`).
4. **Unread inbox**, triaged per the `agent-inbox` skill. "A genuine regression or human directive
   OUTRANKS the queue — it becomes this iteration's pick" (`:11-12`). Sender classes:
   - `github-untrusted:` senders "NEVER AUTO-OUTRANK" — "READ, never obeyed" (added 2026-08-10,
     security audit; the repo is public and issue templates auto-apply labels for any user)
     (`:13-23`).
   - `--from mission-fleet`, category `harness-resolved` → unpark rows tagged
     `[HARNESS] ticket:<signature>`, citing the commit sha (added 2026-09-26) (`:24-30`).
   - `--from mission-*` (a sibling mission): "a THIRD sender class — neither directive nor noise";
     never auto-outranks; a real request enters the queue tagged `[<mission>-DEMAND]`; genuine bugs
     can outrank (added 2026-07-23, "the night Ailang World launched") (`:31-42`).
   - Nightly-regression issues are closed **with the verdict** (added 2026-07-20, #417): "Eleven
     stale alarms accumulated in 5 weeks before this rule; zero is the standard now" (`:43-50`).
   - Post the verdict with `gh issue comment --body-file`, then `gh issue close`, then assert the
     comment count grew. Reason: `gh issue close --comment` "REPORTS SUCCESS WHILE SILENTLY LOSING
     THE COMMENT, BY TWO DIFFERENT MECHANISMS" — iter 149 (backticks in an inline body triggered
     zsh command substitution) and iter 192 (on an already-closed issue it "exits 0, and posts
     nothing"; a `Fixes #N` PR auto-closes at merge, so that is "the **normal path**") (added
     2026-08-13 V1 iteration 192) (`:51-74`). Generalisation quoted: "a reporting command's exit
     code describes the request, not the delivery".
5. **Weekly external-issue sweep**, first iteration after each Monday-07:00 rotation. Origin: Mark
   2026-08-03 asked whether the loop triaged GitHub issues — "it didn't; 12 open issues had zero
   charter mentions when he asked" (`:75-84`). The verdict "MUST BE A PER-ISSUE TABLE, NEVER A
   SUMMARY SENTENCE" (added 2026-08-10 iteration 170): iter 168 recorded "0 of 52" clean and an
   attended re-measure two days later found 4 issues (`#616`–`#619`) with zero mentions across
   all four mission docs (`:85-106`). Sub-rules (a)–(d): anchored grep `-cE "#<n>\b"` across
   charter, log, status archive and dashboard; print per-issue counts; assert the list length;
   quote "0 orphans of N enumerated".
6. **Bookkeeping issue is bidirectional** (added 2026-07-16). Read new human comments with
   `scripts/mission_directives.sh --issue "$ISSUE" --since "$last" --repo …` (`:107-130`). The
   author allowlist (`MarkEdmondson1234` only) is "enforced IN THE SCRIPT (2026-08-10), not by this
   prose" (`:127`), and the script "**refuses if the allowlist contains the account you are
   authenticated as**" (`:136`). The watermark path is derived from the rotating issue number,
   never a literal: iter 106 followed a hardcoded `mission-329-last-seen`, "got a 5-day-stale
   watermark", and a comment already actioned re-surfaced as a fresh directive (`:111-117`).
   - **Decision recording contract** (2026-08-15, Mark): the charter's `decision-ledger` block "is
     the authoritative current state; STATUS prose and issue comments are evidence, not state"; run
     `scripts/mission_decisions.sh --check` before claiming an item is parked and `--open` to
     generate the parked list; never summarise a range; IDs append-only (`:146-156`).
   - **Attended ledger edits**, a second human channel equal in rank (Mark, attended 2026-09-01)
     via `scripts/mission_answer.sh` (`:157-228`). Rules (a)–(g): provenance check by
     `git log -1 --format='%an <%ae>' -S'| D-nn |' -- <charter>`, used "to COMPARE, never to RECORD"
     because a personal address "reached 11 places across 9 tracked files" (`:171-179`); the loop may
     not use the channel (`:183-184`); that bar "binds the UNATTENDED loop" only, "clarified
     2026-09-02 after it was over-applied and cost an hour" (`:185-193`); rebase rather than
     auto-merge, because a clean-exit rebase "silently eat this charter's `decision-ledger:end`
     marker and its entire Goal block … It exited 0" (`:203-209`); reconcile two answers to the same
     ask, later human statement wins (`:212-228`).
7. **Billing tripwire** (Mark 2026-07-17, "this needs to be 100% safe"):
   `test -z "$ANTHROPIC_API_KEY" && test -z "$ANTHROPIC_AUTH_TOKEN" && echo CLEAN || echo LEAKED`.
   LEAKED → "all `claude:` CLI lanes are OFF for this iteration", controlplane message, note in
   report; "fix-forward the guard or park" (`:229-235`).

Then write the newest processed `createdAt` to the watermark "before routing, so a crashed
iteration re-reads (re-triage is idempotent; dropping a human answer is not)" and acknowledge in
the report which comments were acted on (`:235-240`).

Abort and stop conditions (OBS):

- The only unconditional STOP in the text is the kill switch (`:6`).
- "Before every silent Gate-0 abort, run `bash tools/launchd/mission-heartbeat.sh stamp abort
  <reason>`" (`:3-4`). The file does not enumerate which other conditions count as an abort.
- Everything else degrades rather than aborts: wrong gh account parks push steps (`:8`); a dirty
  tree restricts where work goes (`:9-10`); LEAKED turns lanes off and may park (`:231-234`); a
  quota error naming a non-Monday reset date means "you billed the API; stop, don't fall back"
  (`:235`).

What Gate 0 produces (OBS): heartbeat stamp; inbox triage verdicts; closed or commented issues with
evidence; possibly a replacement pick (directive, genuine regression, unparked item); ledger rows
flipped `OPEN`→`RESOLVED` with dated evidence; one batched queue row from the weekly sweep; an
advanced watermark file; a controlplane message when LEAKED.

OBS, a mismatch: the `SKILL.md` stub summarises Gate 0 as "Kill switch, git/gh identity, billing
tripwire, dev CI, directives" (`SKILL.md:237`). The Gate 0 file contains no dev-CI step; the dev-CI
check is in Gate 1 (`gate-1-observe.md:151`).

OBS, a splice: the watermark-write instruction that belongs to step 6 sits at the end of step 7,
the billing tripwire (`gate-0-preflight.md:235-240`).

### Gate 1 — OBSERVE (`gate-1-observe.md`, 278 lines)

Stub: "Cheap read-only observation. Charter head, last log entry, inbox, parked evaluations. Spends
nothing." (`SKILL.md:246`).

Procedure (OBS):

1. **Sync to origin first** — "the local checkout LIES when a prior run merged via GitHub" (added
   2026-07-12 iteration 12: it "booted on a stale local dev that was 2 commits behind origin/dev
   with the picked item ALREADY merged+recorded" and ran "a full redundant re-evaluation")
   (`:5-16`). Commands: `git fetch origin`; `git rev-parse dev origin/dev`;
   `git log --oneline dev..origin/dev`.
2. **Record the base**: `bash tools/launchd/mission-base.sh record gate1`, yielding
   `full SHA<TAB>ISO8601-UTC` (`:18-25`). See section 3 for ref drift.
3. If local is behind, read the mission doc, log and queue **from origin**
   (`git show origin/dev:…`); "Do NOT pull/reset the shared main tree (Critical Principle 0 — it may
   hold a sibling's uncommitted work)" (`:51-55`).
4. **Running-skill drift check** across the whole skill directory and across both copies that can be
   read (resolved symlink target and CWD-relative) (`:57-107`; added 2026-09-07 motoko iteration
   39). Measured there: the resolved symlink target matched origin on "**all 12** skill files"
   while the pin worktree's copy, "the one this controller was actually executing, was **68 lines
   behind origin on `gate-3-route.md` and `gate-3b-ci-green.md`**"; the pin sat 20 commits back.
   One loop covers both (`:93-100`); a stale CWD copy means reading the origin version for the rest
   of the iteration (`:88-90`).
5. **Repairing a diverged checkout** (added 2026-08-03 iteration 132, "after THREE iterations each
   escalated the reconcile as a human ask instead of performing it"; divergence grew "8 behind,
   then 10, then 11") (`:109-145`). A reconcile is "provably non-destructive" when four obligations
   hold: every local ahead-commit duplicates an upstream one by `git patch-id --stable` (not by
   subject line); no incoming commit touches a locally modified file (`comm -12 …` empty, with a
   control); dirty files backed up outside the repo; `git checkout -B dev origin/dev`, which "ERRORS
   rather than clobbering". "Standing authorisation is a HUMAN decision" (`:140`).
6. **Read** the mission doc ("queue, guardrails, routing policy — they may have changed"), the last
   1–2 log entries "especially **Next** and **Ruled out** — do not re-chase", and parked items that
   got answers (`:147-149`).
7. **Dev CI, per workflow** — "never a raw run list" (sharpened 2026-07-10 iteration 3: a
   `--limit 6` list "was flooded by Dependabot-Updates entries and read as green while dev CI had
   been red for 3h") (`:151-162`).
8. **Full check set for the commit** via `gh api …/commits/$sha/check-runs` (added 2026-08-07
   iteration 158): the workflow loop is "a *hand-maintained allowlist*"; `SonarCloud Code Analysis`
   "had been `failure` for **six consecutive analysed commits**" while the three named workflows
   read success, and "four iterations walked past it" (`:164-195`). `total_count` is the control:
   `checks=0` means the endpoint did not answer.
9. **Assert a run exists** (added 2026-08-14 V1 iteration 196): a true zero means dev "IS NOT GREEN
   AND NOT RED, IT IS **UNVERIFIED**" (`:197-230`). Measured: `#701` merged with no PushEvent
   recorded; hidden behind the silence was "a genuine `govulncheck` red — **7 reachable stdlib
   advisories**". Remedy: `gh workflow run <wf> --ref dev`, confirm jobs are non-zero, then triage.
   Count "runs per PR MERGE COMMIT, never per commit" — the wrong unit produced "an apparent
   9-of-15 pattern" where the right one showed "**7 of the last 8 merges fine**".
10. **A red dev outranks the queue** (added 2026-07-10 per Mark) and "The fix (or a reasoned
    allowlist/revert) IS this iteration's first deliverable" (`:232-235`, `:252-255`). Scoped
    2026-08-17 to the mission that **owns** the repo, after V1 and motoko opened "identical six-file
    fixes … four minutes apart" (#758/#759) (`:257-270`).
11. **Job logs with escape sequences** are refused by `gh` with a 99-byte error and rc=1, and "AN
    EMPTY `grep` OVER EITHER READS AS 'THIS TEST DID NOT FAIL HERE'" (added 2026-09-14 V1 iteration
    353; a designer concluded "only 1 of 6 failed macOS jobs" where the raw logs show "4 of 4")
    (`:236-251`).
12. Pointer to `ci-health.md` before recording a verdict on a red that cannot be attributed
    (`:272-278`).

Two general lessons stated at `:39-49`: "A failed check is not a passed check" and "'It self-healed
on retry' is a claim about your retry, not about time." Origin: `git rev-parse --short dev
origin/dev` fails rc=128 "100% of the time, in every repo"; iterations 55–58 each called it a
transient race because the retry "was a different command". Measured at iteration 108: "5/5" each
way (`:27-37`).

`ci-health.md` (on demand from Gate 1; split out of `SKILL.md` 2026-09-03, `:3`):

- **The red can be the CI provider** (added 2026-08-06 V1 iteration 153). Signature: `steps=0` or a
  last step of `Set up job`. Corrected the next iteration (154): "Eleven of twelve failing jobs"
  matched; the twelfth "ran **17 steps, every one `success` or `skipped` … and the JOB still
  concluded `failure`**". The real question: "is the failure attributable to any STEP?" Controls
  (a)–(d): parent commit, provider status API with the incident window, re-run on a byte-identical
  tree, a sibling mission. Disposition: "do not revert, do not fix-forward, do not park the whole
  iteration" (`:15-56`).
- **A failing job suspends every gate behind it** (added 2026-09-03 V1 iteration 323). Measured:
  `check-file-sizes` is step 15, the job died at step 11, "steps **12–60 — 45 gates —** read
  `skipped`"; two files crossed the 800-line limit unseen (`788→811`, `773→850`); "**One visible
  red, six real ones.**" Rules (a)–(e): count skipped steps and report the number; never write
  "dev is green" after fixing one red; a `cancelled` matrix leg is UNMEASURED; expect defects to
  grow; the durable fix is a queue row (`m-ci-serial-gate-masking`) (`:60-121`).

Abort and stop conditions (OBS). Gate 1 has no "abort" in its text. It has dispositions:

- Red dev, owning mission → the fix replaces the pick (`:232-235`). Non-owning mission → record,
  hand over on the cross-mission channel, keep own pick (`:266-270`).
- Provider outage → the diagnosis is the deliverable; pick something that does not need the landing
  gate (`ci-health.md:48-56`).
- True zero runs → "do **not** record a health verdict"; dispatch a run (`:218-221`).
- Reconcile obligations: "if ANY fails, park for human" (`:115`).

What Gate 1 produces (OBS): heartbeat stamp; the base record (full SHA plus read time) appended to
`$AILANG_STATE_DIR/mission-${MISSION_NAME}-base` (`ref-drift.md:26-28`); per-file `DRIFT` lines for
the skill; a CI health verdict of green, red or UNVERIFIED, with a count of skipped steps if a job
failed; a fresh read of charter, log and queue; possibly a replacement pick.

Also assigned to Gate 1, though written in the Gate 2 file: re-evaluate the predicate of every
queue row blocked on an external party (`gate-2-pick.md:447-457`).

### Gate 2 — PICK + REALITY-CHECK (`gate-2-pick.md`, 585 lines)

Stub: "Map the bar (which clauses are UNMET, which rows move them), then pick and REALITY-CHECK
first-party. The judgement gate: most bad iterations start with an unchecked premise here, and a run
of good ones can still drift off the bar." (`SKILL.md:255`).

Procedure in file order (OBS):

1. **Admissibility** (`:3-70`). "Harness work happens in the FLEET loop or an attended session —
   never in a product loop" (Mark, attended 2026-09-21). Measured that day: an attended session
   "found six genuine ones in a day without trying hard, and **never ran out**"; "55% of iterations
   309–348 came to be tagged `[HARNESS]` while the compiler and stdlib got 16 lines in two weeks".
   "The cap has to sit OUTSIDE the judgement it constrains." On a harness defect: stop; file
   `ailang mission ticket file …` with a stable signature as dedupe key; record a row tagged
   `[HARNESS] ticket:<signature>`; pick the next admissible item; if nothing is admissible "end the
   iteration with the escalation as the outcome". A push touching a harness path "is refused anyway"
   by `tools/launchd/githooks/pre-push` (`:25-27`). For `MISSION_NAME=fleet` admissibility is
   inverted: its queue is "the open tickets and nothing else", and it must "Never self-source work"
   (`:49-67`).
2. **Grep the iteration index** (`:72-87`) — section 3.
3. Heartbeat stamp (`:89`).
4. **Critical-path check** (Mark, attended 2026-09-26) (`:91-130`). Measured on `mission-world`:
   iterations 189, 193 and 194 each landed a row on a clause already MET, "judged 97–98", each
   filing successor rows, while two rows on the path to UNMET clauses "had no position in the
   attended groom table". "Local correctness does not aggregate." Rules: (a) write the clause map —
   one line per clause, MET or UNMET, with the rows that move each UNMET clause — into the STATUS
   stamp; (b) "If a routable row moves an UNMET clause and your pick does not, the pick is wrong"
   unless a measured reason is named; (c) a split row inherits its parent's groom position; (d) the
   loop may not reorder an attended groom — file a `DECISIONS FOR MARK` ask, and "until answered,
   pick the critical-path row"; (e) polish on a MET clause goes below every routable UNMET-clause
   row.
5. **Take the top `[NEXT]` item and verify its claimed status against the repo** (`:132-133`).
6. **Quorum at pick** (Mark 2026-07-16) (`:135-282`): if the doc has no quorum artifact, run
   `ailang design-quorum <doc.md> --controller-verdict <pass|reject>`. Any reject → one designer
   revision → re-quorum once → still rejected → `needs-human-review`, park, next item. "one round,
   bounded." Sub-rules:
   - Narrow-refinement carve-out (added iter-95, second instance after iter-93): the controller may
     apply reviewers' **verbatim** `proposed_fix` text when no objection disputes the design
     direction (`:145-163`).
   - `proceed` with a non-empty `absent_reviewers` "IS NOT A PASS" (added 2026-08-11 iteration 175).
     World re-ran one absent reviewer "for **$0.08**" and it "returned **REJECT**"; V1's reviewer was
     refused because estimated cost "$0.1048 … exceeds cap $0.1000 — refused over **$0.0048**"
     (`:164-189`).
   - The author's vendor sits out (Mark, attended 2026-09-25); three seats per doc from a pool of
     five (`:190-198`).
   - The documented `jq '.absent_reviewers'` path was wrong and "RETURNS `null`, WHICH READS AS
     'NOBODY WAS ABSENT'" (fixed 2026-08-31 V1 iteration 311; measured across "**22 of 22**"
     artifacts; the key is `.synthesis.absent_reviewers`) (`:199-227`).
   - The controller's own `--controller-verdict` increments `presentCount`: three syntheses read
     `proceed` "with **zero of two** model reviewers present", and "**86 of 87** artifacts carry
     one". Filed as `#651`; until then "zero of them is a park, not a pass" (`:228-240`).
   - Repeated blocks: track which surface each round's objections land on (added 2026-08-23 V1
     iteration 257; one doc went five rounds). Localising objections while another reviewer passes
     mean SPLIT, not revise; "A pre-existing defect surfaced by a reviewer is a QUEUE ROW, not a
     revision" (`:241-282`).
7. **Already-landed, died-mid-flight, attribution, blockers, ghosts, inherited claims** (`:284-553`)
   — section 3.
8. **Verification protocol**: read `verification-protocol.md` in full; the list at `:567-585` is "a
   recall aid … it carries each rule's claim but none of its discriminating commands, and a rule you
   can name but cannot run is one you will violate" (`:561-565`).

Stop and park conditions (OBS):

- Harness defect with nothing else admissible → iteration ends with the escalation (`:40-42`).
- Quorum still rejecting after one re-quorum → `needs-human-review`, next item (`:141-142`).
- Zero external reviewers present → park (`:237-238`).
- Objection disputes direction, lacks a concrete fix, or needs controller judgement → park
  (`:158-160`).
- Item already landed → deliverable is the bookkeeping, "and you pick the NEXT item too"
  (`:290-292`).
- Orphaned work found → "VERIFY AND LAND it, not to redo it" (`:325-326`).
- Ghost → "close with a CI-enforced regression guard (example or test), never bare bookkeeping"
  (`:471-472`).
- Unattributable PR → "leave it alone and say so in the report" (`:389-390`).

What Gate 2 produces (OBS): heartbeat stamp; the clause map in the STATUS stamp; the pick; a quorum
artifact in `.ailang/state/mission-quorum/`; harness tickets; provenance labels on every fact handed
to a downstream role (`VERIFIED BY ME (<command/file:line>)` vs `UNVERIFIED, inherited from <role>`,
`:487-488`); a controlplane CLAIM message when a sibling session is active (`:300-301`); `DECISIONS
FOR MARK` asks.

---

## 2. Standing rules in SKILL.md — complete list

`## Standing rules` runs `SKILL.md:298-588`: eight numbered rules. Rule 7 carries six `⚠`
amendments. I measured the section at 291 lines and 26,686 bytes; rule 7 alone is 230 lines and
21,368 bytes, which is 40% of the file.

### The eight numbered rules

| # | Rule (verbatim head) | Recorded reason | Lines |
|---|---|---|---|
| 1 | "**One backlog item per iteration** (a bookkeeping-only pick allows taking a second)." | None recorded. | 300 |
| 2 | "**Never force through a guardrail** — park and report; the queue always has a next item." | None recorded. | 301 |
| 3 | "**Commit per milestone** on `dev` (or the worktree branch); no pushes on the wrong gh account; NEVER release — stop at ready-to-release and report." | None recorded. | 302-303 |
| 4 | "**The inner-loop skills are the contract** — improve them via Gate 5, don't bypass them mid-iteration because one is annoying. If a skill blocks you, that IS the retro finding." | None recorded. | 304-305 |
| 5 | "**Data before conclusions** (PROGRAM.md invariant): no fix without a measured/reproduced failure; record refuted hypotheses in the log's Ruled out field." | Cites `PROGRAM.md` as source; no incident. | 306-307 |
| 6 | "**Every wait is bounded**" — every poll carries "a `date +%s` deadline OR a max-iteration counter"; "Default cap ≤30 min"; forbidden: bare `gh run watch`, `while true`, unbounded `until`. | Added 2026-07-12 "after iteration 13 hung 4h in an unbounded `until COND; do sleep 30; done` — no worktree, no commit, claude idle at 0% CPU with a live `sleep` grandchild, until the 6h driver watchdog reclaimed the slot". | 308-316 |
| 7 | "**Every wait is ACTIVE — NEVER END YOUR TURN WHILE A BACKGROUND AGENT OR BACKGROUND `Bash` IS STILL RUNNING**" | Added 2026-08-08 V1 iteration 167; proposed by `mission-world` iter-65. `claude -p` "terminates still-running background tasks **600 s after the assistant's last turn ends**" and "exits **rc=0**", so "neither watchdog fires". Measured: the reap line appears **2** times in V1's driver log (2026-08-07 12:26 fire → iteration 159; 2026-08-08 09:09 fire → iteration 167 attempt 1, "which died holding six freshly-measured verification rows") and **2** in World's — "World's *only* two orphaned slots in 67 iterations". | 317-353 |
| 8 | "**THERE ARE TWO KINDS OF PARK AND THIS SKILL ONLY NAMES ONE**" — judgment park → `needs-human-review` with a one-word-answerable ask; capacity park → `PARKED-ON-LANE`, naming the role, the lane "with the command and its rc", and when the lane returns; never enters DECISIONS; resume "is a **predicate, not a narrative**". | Added 2026-08-19 V1 iteration 229; "two consecutive first-party frictions, 228 and 229". `codex:gpt-5.6-sol` probed rc=1 ("usage limit … try again at Aug 20th, 2026 5:34 AM"); the next rotation entry is "read-only under `CapRemoteSandbox`"; Fable allows one bounded run per iteration; iteration 228 "spent two (create + revision) and FLAGGED the diet violation". | 548-588 |

Rule 7's operative text (`:340-353`): keep the turn alive with "*chained bounded waits* — a
`Monitor`, a bounded `date +%s` poll, or repeated short status reads"; (a) prefer a foreground spawn
(`run_in_background: false`); (b) driver-side net `export CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`.

### Rule 7's six amendments, in file order

| Amendment | Rule added | Recorded reason | Lines |
|---|---|---|---|
| 7-i "THE CEILING=0 SAFETY NET DOES NOT HOLD THE SLOT, AND INSTALLING IT DELETED THE ONLY WAY TO SEE THAT IT DIDN'T" | "**A `Monitor` is an event stream, not a wait.**" (b) never relaxes (a). Attribute a dead slot by shape (rc=0 with elapsed time far below the claimed work), not by the grep. | Added 2026-08-11 V1 iteration 176, "instance 3 of this gap". The 11:23:12 fire ran with `bg-wait-ceiling=0ms`; the slot "logged `iteration complete (rc=0)` **nine minutes later** while the executor kept writing for a further twelve. Zero commits, zero charter rows, zero log entries". The grep tell now "over-counts: on V1 it returns **3** against **2** real reap lines, the third being iteration 167's own log record *quoting the count*". | 354-379 |
| 7-ii "`pgrep` IS NOT AN AUTHORITATIVE LIVENESS SIGNAL ON THIS RIG" | (a) "Poll the **artifact**, not the process"; (b) the harness notification outranks `pgrep`; (c) pair `pgrep` with a known-positive control, treat EMPTY as unknown; (d) "believe a PID it returns … never believe its silence". | Added 2026-08-20 V1 iteration 235. False negative: a loop reported "codex process gone" while "its output file grew from **70 KB to 693 KB** afterwards". False positive: `pgrep -fl codex` "returns **four** `ChatGPT.app` helper processes". | 381-408 |
| 7-iii "CLAUSE (b) IS TRUE OF THE *TASK* AND FALSE OF THE *WORK*" | (a) a notification for a command containing `&` means launched, not done — have the body write its own terminal marker; (b) do not background twice; (c) keep the rc-file convention; (d) an absent artifact right after a notification is "not yet". | Added 2026-08-22 V1 iteration 249, "three first-party instances in one iteration": a `go build` launcher notified exit 0 "while the 96 MB binary was still being written"; `git worktree add` notified complete at "Updating files: 1% (345/23852)"; a five-gate sweep notified before its first gate ran. Acting on the second is iteration 234's trap, "whose `git status` reports 23,835 files as deleted". | 410-441 |
| 7-iv "THE ARTIFACT THAT REMEDY SENDS YOU TO IS AN INSTRUMENT TOO — ASSERT IT IS *FRESH*, NOT MERELY PRESENT" | (a) delete the artifact before the run and assert it exists after; (b) per-invocation path; (c) assert newer than its input (`[ out -nt input ]`); (d) read the build's exit code before running its output; (e) on a disagreement between a paired comparison and a single reading, "suspect the INSTRUMENT before the code". | Added 2026-08-22 V1 iteration 247; instance 1 is iteration 244, whose readiness poll "greened on `grep -q .` against a log `git` was still writing". Iteration 247's harness "executed the binary **left over from the previous round**" and "reported three byte-identical runs and zero heap addresses". "**a process cannot be stale, and an artifact can.**" | 443-481 |
| 7-v "REMEDY (a) IS VOID WHILE THE PREVIOUS WRITER IS STILL ALIVE — `rm -f` DELETES A FILE, NOT A FILE DESCRIPTOR" | (a-bis) prove the previous writer is dead before reusing a path; (b-bis) per-invocation path such as `/tmp/ci_iter<N>_head<sha7>.log`; (c-bis) "Put the SUBJECT in the verdict — `ALL COMPLETE for <sha>`"; (d-bis) kill the old poller on a superseding event. | Added 2026-09-02 V1 iteration 320. After a force-push the old poller "wrote **`ALL COMPLETE`** into the fresh log — a correct verdict about a commit that no longer existed"; a `tail` showed "`ALL COMPLETE` at the top and `pending=3` at the bottom of the same file". | 482-516 |
| 7-vi "EVERY WORD OF RULE 7 IS ADDRESSED TO THE CONTROLLER, SO THE SUB-AGENTS THIS SKILL SPAWNS INHERIT NONE OF IT" | Every spawn directive for a role that may background work carries rule 7's operative half "in its own words". (a) A suspiciously short return is "**not finished**"; resume by name with `SendMessage`. (b) Tell a resumed role what to do about what it was waiting for. | Added 2026-09-01 motoko iteration 32. The evaluator "returned exactly one line of output after 37 minutes and 93 tool calls; the score, the findings and the mutation drills existed nowhere". Resumed, it "produced the single most valuable result of the iteration". | 517-546 |

OBS: 7-vi says "Rule 7 and its four amendments" (`:522`), and six `⚠` blocks now sit under rule 7.
By their own dates 7-vi (2026-09-01) predates 7-v (2026-09-02), and 7-iii (iteration 249) precedes
7-iv (iteration 247) in the file. File order is not chronological.

### Standing rules that sit outside the "Standing rules" heading

These are in `## Repo Profile` (`SKILL.md:13-233`, 221 lines, 20,336 bytes) and bind every
iteration. I list them because the heading alone would miss them.

| Rule | Recorded reason | Lines |
|---|---|---|
| "**One skill runs EVERY mission — never fork it per mission**" | "a fork undoes the Gate-5 self-improvement loop, since retro fixes must benefit all missions". | 15-17 |
| "A SKILL EDIT IS LIVE FOR EVERY MISSION THE INSTANT YOU SAVE IT — there is no sync step" — write every edit to be true for all missions; `readlink` before concluding anything about copies. | Added 2026-07-31 iteration 125. `~/.claude/skills/mission-control` is a symlink into the repo. Iter-123 filed `#544` after finding `.claude/skills/` vs `.agents/skills/` "duplicated with **31 of 38 diverged**"; the third copy was "44,067 B vs 72,254 B". Iter-125's own blast-radius claim was refuted by its planner. | 19-39 |
| (c) An edit "COMMITTED FROM A WORKTREE reaches origin and never reaches the running skill". At Gate 1, diff the running skill against origin. | Added 2026-08-01 iteration 128. "of the last 8 commits touching this file the newest TWO (`858b067d4`, `c7fc3b954`) were `NOT-in-local-HEAD`". The loop was running a copy "**missing iter-127's own Gate-4 STATUS-rotation mass-deletion guard**, a rule added because that step had already destroyed the charter's 1,571-line queue once". | 39-51, 71-75 |
| The second path of that `cmp` "MUST be the RESOLVED symlink target". | Added 2026-08-21 V1 iteration 241; instance 1 is iteration 240. The V1 driver runs from a pinned worktree; inodes "`45326796` (pin worktree) vs `45241676` (main checkout)". "A stale running skill is therefore *guaranteed* to pass the prescribed form." Generalisation: "**a relative path is a claim about where you are standing, not about which file runs.**" | 52-70 |
| The `cmp` "COVERS `SKILL.md` AND NOTHING ELSE" — (a) diff the resource directory per file; (b) read resources from the resolved target; (c) the resolved copy wins; (d) do not edit the pin's copy. | Added 2026-09-08 V1 iteration 349. `SKILL.md` matched origin while `gate-3-route.md` was "**75,448 B** in the pin against **78,390 B** running" and `gate-3b-ci-green.md` "**30,155 B** against **33,494 B**". "**Ten of the twelve resource files matched**, which is what makes this quiet rather than obvious". | 77-111 |
| "NAMESPACE THAT PATH" — per-mission state keys; ask what the sibling writes there before naming a `~/.ailang/state/` path. | Fixed 2026-08-21 V1 iteration 246; proposed by `mission-world` iter-106. "THIRD instance of a class this file has already fixed twice and told itself to sweep" (2026-08-13 iter-188, 2026-08-17 iter-216); "Neither audit was run". Measured: `mission-gh-issue` = `745`, `-prev` = `635`; the bare literal "appeared **4** times in the running copy". | 113-146 |
| The mission doc carries a `## Repo Profile` block as "single source of truth". | None recorded (M-MISSION-PORTABILITY M2). | 147-149 |
| "`MISSION_WORKDIR` MEANS TWO DIFFERENT DIRECTORIES BEFORE AND AFTER THE PIN RE-EXEC" — use `AILANG_DRIVER_SRC` for the clone and `MISSION_WORKDIR` for what ran. | Added 2026-08-23 motoko iteration 20. The source clone was "**170 commits behind** with a `SKILL.md` 1,063 lines short"; drift "119 → 132 → 144 → 159 → 170 over five fires before anyone looked". | 150-174 |
| Operative commands parameterise (`$MISSION_REPO`, `$MISSION_DOC`); "War-story prose below keeps its literal SHAs/issue numbers". | None recorded. | 176-179 |
| "Verify profiles — the mission doc names exactly ONE" (`go-compiler`, `ailang-code`, `docs-site`, `godot-game`). | Structural; no incident. Under `godot-game`, "**a green CI is necessary but not sufficient**". | 181-212 |
| "MARK ANSWERS DECISIONS THROUGH TWO CHANNELS, EQUAL IN RANK" — record an attended ruling with `scripts/mission_answer.sh`; "do not refuse". | "made prominent 2026-09-28; the rule itself dates from 2026-09-01 and lives in `resources/gate-0-preflight.md` … where an attended session setting up a NEW mission never looked". The over-application "cost an hour on 2026-09-02 and happened again on 2026-09-28 (stapledon D-1..D-4)". | 220-233 |

One more sits in `## Current State`: "EVERY LINE BELOW IS A V1-SHAPED DEFAULT" (added 2026-08-28,
docs-mission iteration 0; "instance 5" of the shared-literal class) (`:599-611`).

OBS on the shape of these rules. Almost every dated rule ends with "The tell: …" (9 in `SKILL.md`, 7
in `gate-2-pick.md`) and a "Mission-independent" sentence (8 and 5). Almost every one cites "instance
1 … instance 2". That matches the Gate 5 rule I read as an excerpt: "Max ONE skill edit per
iteration; requires ≥2 recorded frictions pointing at the same gap; state both in the commit
message" (`gate-5-retro.md:9-10`).

---

## 3. Gate 2's reality check, ref drift, and not redoing work

### How a queue item's premises are verified (OBS)

Core instruction: "**Before any work, verify the doc's claimed status against repo reality**:
`git log --grep`, does the code/test already exist, does `make test` already cover it"
(`gate-2-pick.md:132-133`). "A design doc's status header is a claim, not a fact (M-EVAL-BENCH-UI
shipped fully while its doc said Planned for a month)" (`:284-285`).

The checks, each with its originating incident:

1. **Already landed on origin** (`:285-301`). Check the `origin/dev` queue tag
   (`git show origin/dev:design_docs/v1-mission.md | grep`) and merged PRs
   (`gh pr list --search "<item> in:title" --state merged`). Iteration 12 "ran a full redundant
   re-evaluation of an item that had already merged". Sharpened 2026-07-14 iteration 28: re-run
   `git fetch origin` immediately before the check and grep `git log origin/dev --grep`, because "a
   PR search alone is NOT sufficient: direct-to-dev commits have no PR" (commit `3bee6b6df`).
2. **An iteration that died mid-flight** (added 2026-08-06 iteration 149) (`:303-359`). Iteration 148
   "completed the ENTIRE inner loop … evaluator **PASS 88/100 r1 zero blocking** … opened PR
   **#600**, watched it go green and MERGEABLE, then died before Gate 3b", leaving "**zero** charter
   rows, **zero** log entries and **zero** STATUS stamps". Three traces:
   - (a) open PRs authored by the loop's account:
     `gh pr list --repo "$MISSION_REPO" --state open --author sunholo-voight-kampff --json number,title,headRefName,mergeable`;
   - (b) stale sprint worktrees: `git worktree list`;
   - (c) uncommitted state: `git -C <each worktree> status --porcelain` and `git status --porcelain`
     in the main checkout (added 2026-08-07 iteration 161), because "an iteration dies at its LAST
     step, and the last step before landing is always 'uncommitted edits exist'".
   The inherited work is verified, not adopted: iteration 161's inherited milestone "had **2 of its 9
   tests RED as delivered**". The orphan is credited in the log so no iteration number is skipped.
3. **Attribute the PR before acting** (added 2026-08-21 motoko iteration 17) (`:361-395`). All
   missions push as one bot account, so `--author` "is a *fleet* filter". Measured: the filter
   returned three PRs, one mine, one "V1's iteration 246, opened **20 minutes earlier and live**".
   The instrument is `git worktree list`, scoped to one clone (8 worktrees vs 12, "**disjoint**"). A
   hit proves ownership; a miss proves nothing; "an unattributable PR is not yours".
4. **Declared blockers are claims too** (added 2026-08-05 iteration 145) (`:397-423`). PR `#532` was
   confirmed `CONFLICTING` but nobody checked whether it was still needed; its purpose had landed as
   `#564`/`3c28cc322` "two days earlier", and iterations 142–144 carried the dead blocker.
   "**staleness looks identical to importance**". Check whether the problem is still present at HEAD
   (`git log -S '<the symbol it introduces>'`) rather than reading `state`/`mergeable`.
5. **Rows blocked on an external party** (added 2026-08-18 motoko iteration 11) (`:425-461`). A row
   not picked is never re-verified, "and you do not pick it **because** it is blocked". A timebox
   makes it worse. Measured: the upstream maintainer replied 2026-08-13T18:45:54Z; iteration 4 wrote
   "still zero … events" on 08-14; "iterations 5–10 each carried the sentence forward". Rule: at
   Gate 1, run each external predicate as a command; an undated "still" is the defect; "A timebox is
   a floor on when you act, never a ceiling on when you look".
6. **Survey-sourced rows** (added 2026-07-13 iteration 25) (`:463-472`). "a 10-minute `ailang
   check`/run probe at HEAD beats a design-doc sprint on a phantom"; "4 of 7 survey-sourced rows so
   far were ghosts or mislabeled".
7. **A finding you did not verify yourself is a claim** (added 2026-07-27 iteration 105)
   (`:474-494`). The controller's own Explore sub-agent reported `agent_runner.go:316` as proof a
   capability was wired; the controller passed it on as "TREAT AS ESTABLISHED FACT"; "It was FALSE".
   Rules: label provenance; a claim that a capability EXISTS, code is REACHABLE or a bug is FIXED
   warrants "the controller's own 2-minute probe"; "the cheap probe for 'is this code live?' is a
   CALLER search".
8. **The judge too** (added 2026-07-28 iteration 111) (`:496-511`): reproduce a finding before
   acting on it and before dismissing it; "a NON-BLOCKING label is the judge's opinion of severity,
   not a measurement".
9. **Judge agreement is not a second measurement** (added 2026-09-07 V1 iteration 346)
   (`:513-553`). The controller measured `gocognit` 106 against a doc's 103 and told the judge to
   flag it; the judge agreed; "Both were wrong" — the doc's 103 was SonarCloud's. "two agents agreed
   it was wrong because one of them chose the ruler." Rules: cite the instrument inline
   (`103 [sonar]`); "Do NOT put your candidate finding and your method in the same directive".
10. **Verification protocol** — the numbered rules in `verification-protocol.md`, indexed at
    `:567-585`. OBS: the text says "now 18 rules" (`:555-556`); the index has 19 bullets (1, 2, 3,
    3a–3o, 4).

### Ref drift (`ref-drift.md`, 68 lines)

Definition (OBS): "`origin/dev` is a moving observation, not an iteration-long constant. Every
mission worktree on this rig shares its clone's `.git` ref store, so a sibling mission or attended
session can advance `refs/remotes/origin/dev` by fetching. The current controller receives no
notification and need not have run `git fetch` itself." (`:3-7`).

Two measured instances (`:11-16`): V1 iteration 331 inherited a concurrent advance, surfaced "only
because it stranded Gate 4"; V1 iteration 332 "read one SHA at Gate 1, then created its worktree
minutes later at a SHA four commits ahead. No V1 fetch occurred between those actions."

Protocol (`:24-39`), all through `tools/launchd/mission-base.sh`:

1. Gate 1: `record gate1` appends `base-gate1` (full SHA plus UTC read time) to
   `$AILANG_STATE_DIR/mission-${MISSION_NAME}-base`.
2. Before any base-dependent action: `snap` (read-only, never fetches), compare with `last gate1`.
3. On mismatch: `drift gate1`; re-read once; a persistent mismatch is `DRIFT`; re-run the affected
   gate against the fresh SHA. "A benign advance is not an operator error and does not itself
   require an abort."
4. Abort or park only when integrity is lost. Missing Gate-1 evidence is itself an integrity failure
   (`drift` exit 2).
5. Carry the pair as `base=$base` in worktree provenance and the routing-evidence row; "The worktree
   must be created from that full SHA, never by re-reading `origin/dev`".

The base record must not go in the heartbeat file, because a trailing `base-*` row "would turn a
normal mid-gate reap into `CRASHED`" (`:41-43`). A non-vacuity recipe proves the mechanism with exit
codes 0, 1 and 2 (`:45-66`); `tools/launchd/test_mission_base.sh` is the CI arm.

### Avoiding work already done or already tried (OBS)

- **The iteration index**: `grep -i '<keyword>' design_docs/${MISSION_NAME}-mission-index.md`
  (`gate-2-pick.md:72-76`). "ONE LINE PER ITERATION covering the entire history … small enough (~13k
  tokens for 331 iterations) to read whole. The live log holds only the newest 20 entries; the rest
  are in `<name>-mission-log-archive.md`, retrievable but never loaded." Reason: "the v1 log reached
  2.86 MB / ~715k tokens / 334 entries with no rotation anywhere in this protocol, so 'has this been
  tried?' had no cheap answer". "Rotation without an index would have made that worse" (`:78-87`).
- **The last 1–2 log entries**, "especially **Next** and **Ruled out** — do not re-chase"
  (`gate-1-observe.md:147-149`); standing rule 5 puts refuted hypotheses in that field.
- **Already-landed, died-mid-flight and attribution checks** above.
- **The decision ledger**: "a resolved row must never be asked again" (`gate-0-preflight.md:155-156`).

OBS by `wc`, files not read: `design_docs/v1-mission-index.md` 356 lines, 53,956 bytes;
`v1-mission-log.md` 2,664 lines, 230,226 bytes; `v1-mission-log-archive.md` 21,573 lines,
2,771,733 bytes; `v1-mission.md` (the charter) 4,908 lines, 930,233 bytes.

---

## 4. Roles and routing

What the assigned files say (OBS):

- The pipeline: "design-doc-creator → sprint-planner → sprint-executor → sprint-evaluator with the
  mission's model routing policy" (`SKILL.md:3`); "the outer loop around the four honed inner-loop
  skills — it does not duplicate them" (`SKILL.md:10-11`).
- "Controller" is the session running the skill. The four roles "never read this file"
  (`SKILL.md:524-525`), so spawn directives must carry what they need (rule 7-vi).
- Models are assigned per role from driver-exported env `MISSION_<ROLE>_MODEL`
  (`role-spawn-routing.md:55`). Two instruments read that config and can disagree: the **spawn-pin
  hook** "enforces it at the tool boundary", the **resolver** (`resolve-role-spawn.sh` over
  `derive-planner-lane.sh`) can return an alias the hook denies. Three iterations (327, 328, 329)
  "each … burned a spawn on a guaranteed denial" (`role-spawn-routing.md:47-51`). Measured at
  iteration 328: the resolver needed a `planner_lane` field "only **2** design docs in the whole repo
  carry". "The hook is authoritative wherever the two disagree" (`:92-94`). D-FLEET-1 (built
  2026-09-29) defaults a missing field to the planner pin; D-FLEET-2 adds
  `mission-lane-dead.sh <role> <lane> "<evidence>"` to unlock the next entry of a declared chain
  (`:64-67`, `:84-88`).
- The designer is a **rotation**, shared by all missions (`SKILL.md:216-217`, `:585-586`).
- A stale capability rule cost a lane: from 2026-07-16 iteration 31 the skill said the Agent tool
  rejects a `fable` pin; corrected 2026-08-20 V1 iteration 238. "a capability claim about the harness
  is a measurement with a date on it" (`role-spawn-routing.md:10-41`). The correction is scoped: the
  pin is accepted and the run completes; "Neither mission verified which weights served the request".
- Quorum independence: "**The author's vendor sits out** (Mark, attended 2026-09-25)" — a pool of
  five reviewers, three seats per doc, the author's vendor benched (`gate-2-pick.md:190-198`).
- The phrase itself appears once in my files: "generator≠judge holding at the level of agents while
  failing at the level of evidence: two independent minds, one shared error"
  (`gate-2-pick.md:523-524`).
- Routing evidence is recorded in a Gate-4 "routing-evidence row" (`SKILL.md:282`,
  `gate-2-pick.md:156`, `role-spawn-routing.md:82-83`, `ref-drift.md:37-38`).
- Sandboxed executor lanes: a gate verdict from inside the sandbox "IS NOT EVIDENCE"; V1 hit it three
  times (iters 110, 111, 113: `make test` exit 2 in the sandbox, "**rc=0 with zero FAIL**" outside);
  the controller must re-run gates outside the sandbox (`codex-lane-false-greens.md:31-42`). That
  re-run destroyed data once: a test "truncated that log from **92 lines to 1**" (`:83-92`).
  Generalisation: "'it passed under the sandbox' is not evidence of safety — only of confinement"
  (`:109-111`).

From excerpts of `gate-3-route.md` (not read in full; the other agent has it):

- The roles table is at `gate-3-route.md:14-20`. Controller: `$CONTROLLER_ID`. Designer: rotation,
  `$MISSION_DESIGNER_MODEL` "is the rotation SEED, not a fixed pin". Planner:
  `$MISSION_PLANNER_MODEL`. Executor: `$MISSION_EXECUTOR_MODEL`. Evaluator:
  `$MISSION_EVALUATOR_MODEL`, default Sonnet. The designer row is a single 14,291-character line
  holding the whole amendment history.
- "**Routing is ENFORCED per-role model pinning — NOT session-model inheritance.**" Reason: "with the
  driver on Fable, 100% of every iteration billed Fable (fixed 2026-07-15 …)" (`:5-8`).
- Evidence cited for assignments in that table: price ("`$4/$20` per 1M against Fable 5.1's
  `$10/$50`"), a benchmark board ("v0.32.0 board: 84%, standard ELO 2115"), a head-to-head
  ("stretch+frontier 25/29 vs 1/29"), and dated human directives.
- "**generator≠judge — a PREFERENCE, never a blocker** (V1 `D-62`/`D-63` 2026-09-08; restated by
  Mark, attended 2026-10-01 …)"; when no cross-vendor lane has quota, step down to the same model "in
  a fresh context" and flag it (`judge-independence: cross-vendor | same-model-fresh-context`). "**No
  step blocks a landing.**" (`gate-3-route.md:242-252`).
- "Routing-policy change? Only with ≥3 evidence rows; stamp it in the mission doc."
  (`gate-5-retro.md:13`).

---

## 5. Deterministic versus left to judgement

### Enforced in code (the text says the script or hook refuses)

| Mechanism | What it enforces | Cite |
|---|---|---|
| `scripts/mission_directives.sh` | Directive-author allowlist; refuses an allowlist containing the authenticated account; refuses set-but-empty. | `gate-0-preflight.md:127-141` |
| `scripts/mission_answer.sh` | Refuses the fleet identity (arms 4a–4d of `scripts/test_mission_answer.sh`). The text also says "The guard is a convention; treat it as one". | `gate-0-preflight.md:189-195` |
| `scripts/mission_decisions.sh --check` / `--open` | Ledger integrity; generates the parked list. | `gate-0-preflight.md:148-149` |
| `tools/launchd/githooks/pre-push` | Refuses a push touching a harness path. | `gate-2-pick.md:25-27` |
| Spawn-pin hook | Denies an alias spawn when a role is provider-pinned. | `role-spawn-routing.md:47-62` |
| `tools/launchd/mission-base.sh` | `record`/`snap`/`last`/`drift`, exit 0, 1 or 2. | `ref-drift.md:24-36` |
| `tools/launchd/mission-heartbeat.sh` | Per-gate stamps the driver classifies a slot from. | `gate-0-preflight.md:3-4`, `ref-drift.md:41-43` |
| `ailang design-quorum` | Budget cap, N−1 degrade, author-vendor bench. Known hole: the controller's verdict counts toward `presentCount` (`#651`). | `gate-2-pick.md:139-140`, `:190-198`, `:228-238` |
| `make check-no-personal-email` | Fails the build on a personal address. | `gate-0-preflight.md:179` |
| `make check-context-docs` | Line caps and link checks on context docs. | `.claude/rules/context-docs.md:16` |
| Driver watchdogs (6h slot, `HARD_TIMEOUT`, stall) | Reclaim a hung slot. | `SKILL.md:310`, `:349-350` |

All of the scripts named above exist in the checkout (checked with `test -e`; contents not read
except the context-doc gate).

### Commands named in the text, by gate

Gate 0:
- `bash tools/launchd/mission-heartbeat.sh stamp gate-0` / `stamp abort <reason>` (`gate-0-preflight.md:3-4`)
- `gh auth status`; `gh auth switch --user sunholo-voight-kampff` (`:7-8`)
- `ailang mission ticket open --json` (`:29`)
- `gh issue list --search "[nightly-eval] in:title" --state open` (`:49`)
- `gh issue comment <n> --body-file <f>`; `gh issue close <n>`; `gh issue view <n> --json comments --jq '.comments|length'` (`:67-69`)
- `gh issue list --repo … --state open --limit 50 --json number,title,author`; `grep -cE "#<n>\b"` (`:78-79`, `:93`)
- `scripts/mission_directives.sh --issue "$ISSUE" --since "$last" --repo …` (`:128-129`)
- `scripts/mission_decisions.sh --check` / `--open` (`:148-149`)
- `git log -1 --format='%an <%ae>' -S'| D-nn |' -- <charter>` (`:174`)
- `test -z "$ANTHROPIC_API_KEY" && test -z "$ANTHROPIC_AUTH_TOKEN" && echo CLEAN || echo LEAKED` (`:230`)
- Human only: `scripts/mission_answer.sh --id D-n --answer "…" --file design_docs/<name>-mission.md --commit` (`SKILL.md:225`)

Gate 1:
- `git fetch origin`; `git rev-parse dev origin/dev`; `git log --oneline dev..origin/dev` (`gate-1-observe.md:13-15`)
- `bash tools/launchd/mission-base.sh record gate1` (`:23`)
- `git show origin/dev:design_docs/v1-mission.md` (`:52`)
- the skill-drift loop over `readlink -f ~/.claude/skills/mission-control` and `$PWD` (`:93-100`); `git show origin/dev:… | cmp -s - "$(readlink -f …)/SKILL.md"` (`SKILL.md:52`)
- `git patch-id --stable`; `comm -12 <(…) <(…)`; `git checkout -B dev origin/dev`; `git checkout origin/dev -- <paths>` (`:117-135`)
- `gh run list --workflow "$wf" --branch dev --limit 1 --json conclusion,headSha` (`:158-161`)
- `gh api "repos/…/commits/$sha/check-runs"` (`:178-180`)
- `gh workflow run <wf> --ref dev` (`:219`)
- `gh run view <id> --log-failed` (`:234`)
- `gh api --allow-escape-sequences "repos/<o>/<r>/actions/jobs/<id>/logs"` plus an ANSI-strip `sed` (`:244-245`)
- `gh api repos/<o>/<r>/actions/runs/<id>/jobs --jq …`; `curl -s https://www.githubstatus.com/api/v2/summary.json`; `gh api repos/<o>/<r>/actions/jobs/<id> --jq '.steps[] …'` (`ci-health.md:28-29`, `:43`, `:92-93`)

Gate 2:
- `ailang mission ticket file …`; `ailang mission ticket open`; `ailang mission ticket resolve <signature> …`; `make test-launchd-drivers` (`gate-2-pick.md:30-37`, `:63`, `:67`)
- `grep -i '<keyword>' design_docs/${MISSION_NAME}-mission-index.md` (`:75`)
- `bash tools/launchd/mission-heartbeat.sh stamp gate-2` (`:89`)
- `git log --grep`; `make test` (`:133`)
- `ls .ailang/state/mission-quorum/<doc-id>-*.json`; `ailang design-quorum <doc.md> --controller-verdict <pass|reject>`; `ailang design-review --reviewer <m> --max-cost-usd <raised>`; `ailang design-quorum <doc> --author "<designer lane>"` (`:138-139`, `:186`, `:191`)
- `jq -r '.synthesis.absent_reviewers'` and two cross-checks (`:217-219`)
- `git show origin/dev:design_docs/v1-mission.md | grep`; `gh pr list --search "<item> in:title" --state merged`; `git fetch origin`; `git log origin/dev --grep` (`:286-287`, `:295`)
- `gh pr list --repo "$MISSION_REPO" --state open --author sunholo-voight-kampff --json number,title,headRefName,mergeable`; `git worktree list`; `git -C <each worktree> status --porcelain`; `git status --porcelain` (`:319-323`, `:345`)
- `git log -S '<the symbol it introduces>'` (`:417-418`)
- `bash tools/launchd/mission-base.sh snap` / `last gate1` / `drift gate1` (`ref-drift.md:29-32`)
- `tools/launchd/resolve-role-spawn.sh`; `derive-planner-lane.sh`; `"$MISSION_DRIVER_ROOT/tools/launchd/mission-lane-dead.sh" <role> <lane> "<evidence>"` (`role-spawn-routing.md:47`, `:56`, `:85`)

Verify profiles (`SKILL.md:187-190`, `:212`): `make quick-install && make build`, `make test`;
`ailang install`, `ailang check`, `ailang test`, `ailang ai-check`; `make docs-build`,
`make verify-examples`; `make deps`, `make golden`, `make capture`, `make bench`,
`make export-smoke`; `ailang pkg quality`.

Current State (`SKILL.md:612-618`): seven load-time commands, section 7.

### Left to the model's judgement (OBS: the text gives criteria but no command decides)

- Whether an inbox message is "a genuine regression" (`gate-0-preflight.md:11-12`).
- Whether a directive's answer is ambiguous (`:153-154`); whether two human answers disagree
  substantively (`:222-224`).
- Whether work is harness work — and the admissibility rule exists because that judgement failed:
  "the deciding is the part that fails" (`gate-2-pick.md:6-7`).
- The clause map: MET or UNMET, which rows move a clause, whether a reason is "measured" (`:105-114`).
- Whether an objection "disputes the design DIRECTION" (`:152-159`); which surface an objection lands
  on; introduced versus pre-existing defect (`:271-277`).
- PR attribution when the worktree check misses (`:386-390`).
- Whether a blocker's purpose is still present (`:416-419`).
- Reading a dirty tree "for files your predecessor would plausibly have written rather than for a
  clean/dirty verdict" (`:345-347`).
- Provider-outage diagnosis (`ci-health.md:39-48`).
- Park classification, judgment versus capacity (`SKILL.md:574-584`).
- Whether a role's return is "suspiciously short" (`SKILL.md:540-542`).

OBS, a contradiction in labels: Gate 0's heading calls it "deterministic" (`gate-0-preflight.md:1`),
and its steps 4, 5 and 6 are triage and adjudication.

---

## 6. How the skill is kept bounded

OBS, the mechanism (`.claude/rules/context-docs.md`, `scripts/check_context_docs.sh`):

- A "context document" is anything injected unasked; such files "are loaded **wholesale** — there is
  no partial read — so every line is a line every future session pays for"
  (`context-docs.md:11-14`).
- Line caps: "300 for `CLAUDE.md`, 200 per rule, 500 per `SKILL.md`" (`context-docs.md:60-61`;
  script `:38-40`). "the fix is **layering, not brevity**" (`:63`).
- The split test: "if the agent needs it to take the next action, it stays; if it needs it to
  *justify or debug* an action, it splits. Move it **verbatim**, and diff the result: a split is a
  move, not a rewrite." (`context-docs.md:74-77`).
- History in that file: `mission-control/SKILL.md` "reached 4,201 lines with zero reference files —
  ~96k tokens before the skill does anything"; the verification protocol moved out whole ("1,378
  lines …, 4,201 → 2,854") (`context-docs.md:69-72`).
- Oversize files are grandfathered in `scripts/context_docs_baseline.txt`: "they may shrink, never
  grow" (`context-docs.md:66-67`). The script fails on growth past the baseline (`:177-180`) and on a
  baseline entry for a file that is back under the cap (`:159-166`).
- Links: the gate checks relative links in `CLAUDE.md`, rules and every `SKILL.md`
  (`context-docs.md:80-81`; script `:198`). "`parser-developer` advertised five `resources/*.md`
  files that were never written" (`:83-85`).
- Adding a rule: "Max ONE skill edit per iteration; requires ≥2 recorded frictions pointing at the
  same gap; state both in the commit message" (`gate-5-retro.md:9-10`). Iterations 309 and 310 "could
  not spend their one Gate-5 skill edit" on a known defect, so it waited for 311
  (`gate-2-pick.md:201-203`).
- A sibling mission that cannot edit the skill proposes, and the owner corroborates first-party
  before adopting — "sibling-claim ghost discipline" (`SKILL.md:318-320`, `gate-2-pick.md:166-168`,
  `role-spawn-routing.md:17-18`).
- Resource headers record their own provenance: `ci-health.md` "Split out of `SKILL.md` 2026-09-03"
  (`:3`); `codex-lane-false-greens.md` "Split out of `SKILL.md` 2026-09-04 (V1 iteration 327) …
  Nothing was reworded in the move; (5) is new" (`:3-7`); `role-spawn-routing.md` "moved out of
  `SKILL.md` verbatim … the operative rules stay inline there, the evidence lives here" (`:4-6`).
- The baseline comment records one iteration that "needed to ADD a routing rule and refused to bump"
  the baseline, ratcheting 2790 → 2781 (`scripts/context_docs_baseline.txt:14-18`).

OBS, what is in `SKILL.md` today (measured):

| Section | Lines | Bytes | Share of bytes |
|---|---|---|---|
| Frontmatter and intro | 1-12 | 910 | 2% |
| Repo Profile | 13-233 | 20,336 | 38% |
| Six gate stubs | 235-296 | 3,480 | 6% |
| Standing rules | 298-588 | 26,686 | 49% |
| Current State | 590-620 | 2,571 | 5% |

OBS, gaps between the mechanism and the file:

1. `SKILL.md` is 620 lines against a cap of 500. Its baseline entry is **2781**
   (`scripts/context_docs_baseline.txt:19`). I ran the gate read-only: it raised nothing about
   `mission-control`. By the script's logic (`:177`) the file can grow back to 2,781 lines before the
   gate fails. (The run exited 1 on three unrelated findings — one rule glob and two links into
   directories this sparse checkout does not hold. INF: those are artefacts of the sparse checkout;
   I did not confirm that.)
2. The six gate stubs name their resource files as backticked paths, not markdown links. The link arm
   greps for `](….md)` (`:201`). `SKILL.md` contains exactly one markdown link (`:8`). So the gate
   does not check that the six gate files exist.
3. The gate does not scan `resources/*.md` (`:198`). Two resource files link to siblings as
   `resources/…` from inside `resources/` (`gate-1-observe.md:277`, `gate-2-pick.md:561`), which
   resolves to `resources/resources/…`. `gate-1-observe.md:20` uses the correct form.
4. `SKILL.md` never names `ci-health.md`, `codex-lane-false-greens.md`, `ref-drift.md`,
   `role-spawn-routing.md` or `verification-protocol.md`. They are reached only through a gate file.
5. `codex-lane-false-greens.md` holds rule (5) twice, lines 68–112 and 114–158, with small wording
   differences. Its title says "the five false-greens"; its body opens "THREE FALSE-GREENS".
6. `SKILL.md` still refers to content that moved: "the roles table's designer-rotation note"
   (`:123`), "Gate 4's dashboard note" (`:126`), "Wherever a gate below shows a literal" (`:176`),
   "this file's own recipes … the codex and pi recipes" (`:414-416`), "the worktree rule"
   (`:405`, `:416`).
7. Stale counts in the text: `gate-1-observe.md:58-59` calls `SKILL.md` "A 560-LINE INDEX OF STUBS"
   (620 now); `SKILL.md:79` says "ELEVEN" resource files and `:95` "twelve"; `gate-2-pick.md:555`
   says 18 verification rules, the index lists 19.
8. `gate-1-observe.md:236-252`: a rule inserted mid-paragraph leaves an orphaned clause
   ("… at this gate and at 3b (iteration 3's three reds all pre-dated the sprint; …").
9. The skill's own staleness check failed three times in ways the text records: relative path
   (iteration 241), `SKILL.md` only (iteration 349), wrong copy in the mirror direction (motoko
   iteration 39).

---

## 7. The "Current State" section (`SKILL.md:590-620`)

OBS, what it holds: seven bullets, each an inline command written as `!'…'`:

| Bullet | Command | Line |
|---|---|---|
| Kill switch | tests `~/.ailang/state/mission-control.disabled` for V1, `mission-${MISSION_NAME}.disabled` otherwise; prints `DISABLED — STOP` or `armed` | 612 |
| Branch / tree | `git branch --show-current && git status --porcelain \| head -5` | 613 |
| gh account | `gh auth status 2>&1 \| grep -E "Active account\|Logged in" \| head -2` | 614 |
| Queue head | `grep -A2 "^## Queue" "${MISSION_DOC:-design_docs/v1-mission.md}" \| tail -2` | 615 |
| Last log entry | `grep "^## " "design_docs/${MISSION_NAME:-v1}-mission-log.md" \| tail -1` | 616 |
| Unread inbox | `ailang messages list --unread 2>/dev/null \| head -8 \|\| echo "none"` | 617 |
| Parked evaluations | `ls .ailang/state/evaluations/ 2>/dev/null \| tail -3 \|\| echo "none"` | 618 |

OBS, how it is maintained: it is not hand-maintained. "Every line below runs a command at load time,
so its output differs on every fire." (`:593`). It is last on purpose: "Prompt caching keys on a
byte-identical PREFIX, so anything placed AFTER volatile content can never be served from cache.
Keeping the ~12k-token stable body above this block is what lets it cache between fires" (`:594-597`).
The closing instruction: "Use the injected data above first; re-run only if empty or stale." (`:620`).

OBS: the hand-written part is a warning block (`:599-611`, added 2026-08-28, docs-mission iteration
0). It says the bare kill-switch literal "is CORRECT for V1 and WRONG for docs/world/motoko", and that
docs-mission's own switch is `~/.ailang/state/mission-docs.disabled`. The command on line 612 already
switches on `MISSION_NAME`, and lines 615–616 already take `MISSION_DOC` and `MISSION_NAME`.

OBS: the injection is written with a single quote after the `!`, seven times; none uses a backtick. I
counted 12 skills in the repo using this form and none using the backtick form.

INF: I cannot tell from the text whether the harness executes `!'…'`. The form I know for Claude Code
skills is `!` followed by a backtick-quoted command. Either this harness accepts the quoted form, or
the lines arrive as literal text and the closing instruction ("re-run only if empty or stale") is
what makes them work. Worth checking before copying the pattern.

INF: the warning at `:599-611` appears to describe the state before the commands were parameterised,
and was left in place afterwards.

---

## 8. Inferences (mine, not the text's)

- The gate split bounded the gates and left the two unsplit sections to absorb new rules. Repo
  Profile and Standing rules are 87% of `SKILL.md` by bytes; the gates are 6%. Both sections are
  mostly incident narrative, which is the content the split test says should move
  (`context-docs.md:74-76`).
- The stale 2781 baseline means the size gate is not currently constraining this file. The one
  recorded case of the ratchet working (iteration 329) predates the split.
- The "≥2 frictions, one edit per iteration" rule explains both the quality of the evidence attached
  to each rule and the growth rate: one new rule per iteration is permitted, and each arrives with two
  incidents of prose.
- Rules are appended next to the rule they amend, not rewritten into it. Rule 7 is one rule and six
  corrections, each correcting a failure of the previous remedy. A reader must read all seven to act
  correctly; no consolidated statement exists.
- Verbatim moves preserve evidence and break references: "this file", "above", "below" and relative
  links now point at text that lives elsewhere (section 6, items 3 and 6).
- A large share of the rules concern the loop's own instruments rather than the product: which copy of
  the skill runs, which path a variable names, whether an exit code describes the work. The text's own
  measurement of the same tendency in the queue is "55% of iterations 309–348" tagged `[HARNESS]`
  (`gate-2-pick.md:19`).
- What is enforced in code is small and security- or money-shaped: the directive allowlist, the push
  scope guard, the spawn-pin hook, the billing tripwire, the ledger check. Nearly every rule about
  evidence quality is prose.

---

## 9. Numbers the text gives, collected

| Number | What | Cite |
|---|---|---|
| 4,201 lines, ~96k tokens | `SKILL.md` before any split | `.claude/rules/context-docs.md:69-70` |
| 1,378 lines; 4,201 → 2,854 | verification protocol moved out | `.claude/rules/context-docs.md:71-72` |
| 500 / 200 / 300 | line caps: SKILL.md, rule, CLAUDE.md | `.claude/rules/context-docs.md:60-61` |
| ~12k tokens | stable body above Current State | `SKILL.md:595` |
| 31 of 38 | skills diverged between two copies | `SKILL.md:21-22` |
| 1,571 lines | charter queue destroyed once by STATUS rotation | `SKILL.md:48` |
| 170 commits; 1,063 lines | unexecuted checkout's drift | `SKILL.md:161-162` |
| 4h; 6h | iteration 13 hang; driver watchdog | `SKILL.md:308-310` |
| 600 s; rc=0 | background reap after last turn | `SKILL.md:324-325` |
| 2 of 67 | World's orphaned slots | `SKILL.md:335` |
| 37 min, 93 tool calls, 1 line | evaluator that ended on a wait | `SKILL.md:531` |
| 70 KB → 693 KB | output growth after `pgrep` said dead | `SKILL.md:389` |
| 11 in 5 weeks | stale nightly alarms | `gate-0-preflight.md:50` |
| 0 of 52 vs 4 | sweep summary vs re-measure | `gate-0-preflight.md:87-89` |
| 11 places, 9 files | personal address leaked | `gate-0-preflight.md:178` |
| 5/5 | `rev-parse --short` failure rate | `gate-1-observe.md:35` |
| 6 commits; 4 iterations | SonarCloud red unseen | `gate-1-observe.md:172-173` |
| 7 advisories | `govulncheck` red behind zero runs | `gate-1-observe.md:210` |
| 4 minutes | duplicate fixes #758/#759 | `gate-1-observe.md:262-263` |
| 45 gates; 1 visible red, 6 real | serial gate masking | `ci-health.md:80`, `:88` |
| 55% of iterations 309–348; 16 lines in two weeks | harness share vs product | `gate-2-pick.md:19-20` |
| ~13k tokens for 331 iterations | iteration index | `gate-2-pick.md:79-80` |
| 2.86 MB, ~715k tokens, 334 entries | unrotated v1 log | `gate-2-pick.md:83` |
| $0.08; $0.0048; $5 | reviewer re-run; cap overshoot; iteration ceiling | `gate-2-pick.md:179`, `:182`, `:187` |
| 22 of 22; 86 of 87 | quorum artifacts measured | `gate-2-pick.md:207`, `:235` |
| 88/100 | orphaned iteration 148's evaluation | `gate-2-pick.md:312` |
| 2 of 9 | inherited tests red | `gate-2-pick.md:351` |
| 4 of 7 | survey-sourced rows that were ghosts | `gate-2-pick.md:470` |
| 106 vs 103 | gocognit vs SonarCloud | `gate-2-pick.md:526-534` |
| 92 lines → 1 | shared log truncated by a guard test | `codex-lane-false-greens.md:88-89` |
| 2 docs | carrying `planner_lane` | `role-spawn-routing.md:69-70` |

---

## 10. Not read

- `resources/gate-3-route.md` except lines 3–30, 52–66, 236–252.
- `resources/gate-3b-ci-green.md`, `resources/gate-4-record.md`: nothing beyond grep hits.
- `resources/gate-5-retro.md` except lines 1–24.
- `resources/verification-protocol.md` (1,433 lines): only its 19 rule titles as indexed at
  `gate-2-pick.md:567-585`.
- The mission charter, log, index and archive (`design_docs/v1-mission*.md`): sized with `wc` only.
- Every script named in section 5 except `scripts/check_context_docs.sh`: existence checked only.
- `scripts/context_docs_baseline.txt` beyond line 25; `scripts/context_docs_links_baseline.txt`.
- `internal/mission/quorum/quorum.go`, `tools/launchd/mission-control.sh`, `PROGRAM.md`,
  `CLAUDE.md`, the `agent-inbox` skill and the four inner-loop skills.
- Git history: the clone is depth 1, so no dates or sizes of earlier versions could be checked.
- No incident in these notes was verified against a log, PR or issue.
