# Handoff: PLAN-003 P1 is done, P3 is two parts in, and the delegation view finally shows the plan

Written 2026-09-12 about the live run of 2026-09-08. Branch
`arniwesth/013-plan003-and-herdr`, HEAD `ca42142`. Nothing pushed.

**Read this first if you are restarting the orchestrator:** §6 has the prompt, and §2 has the one
trap — the memory patch is applied to the file and is NOT in effect.

---

## 1. What landed

**PLAN-003 P1 is complete.** Six parts, six commits, each with its gate evidence in its commit
message:

| | commit | |
|---|---|---|
| P1 Part 1 | `cbf50f3` | the acceptance test, red first |
| P1 Part 2 | `110c3b7` | `StepBudgetExhausted` code, message discriminator deleted |
| P1 Part 3 | `784f354` | `journal.ail` — `Continuation`, `RunIdentity`, `FinalState`, the `[Message]` codec |
| P1 Part 4 | `06b07ca` | `suspended`/`final`, `c2_suspend`, `RunSuspended`, the one anchor re-baseline |
| P1 Part 5 | `253438b` | loop identity and the in-process resume |
| P1 Part 6 | `20c3e87` | the host's `run_suspended` case, and the first judging number |

**P3 is two parts in:** `54e44ff` (Part 1, the vocabulary — five variants, rows, goldens, no
emits) and `c5f0893` (Part 2, `fold_journal`, its refusals and the `JournalFold` family, red by
design). Part 2's red is correct: the family is red on every fixture until Part 3's emits land.

**So the issue this plan exists for is half-repaired.**
`.agent/issues/step-budget-exhaustion-starts-a-fresh-session.md` is fixed **in memory** — a run
that reaches its budget now suspends with its history and `continue` resumes the same run. It is
NOT fixed across a process death; that is P3, and P3 is where the work now is.

**ADR-002 was reconciled onto this branch** (`80743bc`), which carried it from v3 to v4.1 plus the
v4 review — the branch had been reading a superseded decision. `b48e2f2` adds **v4.2**, one
Consequences paragraph and no decision: the testability argument for D2, that waiting is a
DURATION today and DST erases duration, so the polling cost this ADR removes is invisible to
`make dst` by construction and would stay invisible under any fixture the harness could hold.

**The anchors were re-baselined twice in two hours** (`06b07ca`, then `cd1bdfd`), where §0.2 priced
one. The second is merge order, not plan drift: Part 4 re-baselined on the plan branch and the 021
lineage was merged afterwards. Both ledger entries say so. Work continues on the merged branch, so
there is no third.

## 2. What is NOT live, and this is the trap

**The memory patch is applied to the file and not in effect.**
`.devcontainer/agent_confined/docker-compose.yml` now reads `${AGENT_MEM_LIMIT:-24g}` (uncommitted
in the working tree), but as of writing:

```
/sys/fs/cgroup/memory.max   8589934592   (still 8 GiB — the container has not restarted)
free -g                     total 15     (the OrbStack VM has not been raised)
```

Two things must both happen, and the second is the one that is easy to miss: **restart the
container** to pick up the compose change, and **raise the OrbStack VM to at least 32 GB** first. A
24 GiB ceiling on a 15 GiB VM never binds, which does not grant memory — it retires the host-DoS
containment those lines exist for, silently. `PATCH-agent-confined-mem-limit.md` in
`../021_herdr_delegation/` carries the reasoning; the patch writes the caveat into the compose
comment because compose cannot check it.

**The dagr graph is one part behind.** `.dagr/run-plan003.json` records through `P3P1` and shows
`P3P2` queued, with `generated_at: 2026-09-08T20:16:00Z` — it froze when the orchestrator was
killed at 20:48. `c5f0893` landed after. Reconcile against `git log` before starting; §6's prompt
says how and why.

## 3. What killed the last session

The container OOM-killed it. `/sys/fs/cgroup/memory.events` reads `max 2137700`, `oom_kill 1`
against an 8 GiB ceiling; the log ends mid tool-phase at step 215 of a 1200 budget with no error,
no `run_summary` and no exit manifest, and the delegate was never reaped. Full evidence and a
four-step triage: `../../issues/a-killed-motoko-process-exits-silently.md`.

The half of that issue belonging to this tree is `runtime-process.ts:620` — the child's `exit`
event is bound with a callback taking **no arguments**, discarding both code and signal, so a
SIGKILLed runtime cannot be told from a finished one. Its sibling at `:701` reads `code`, which is
what makes the omission look accidental.

**Nothing was lost.** Each part commits as its own last act, so the orchestrator's context died and
the record did not. That is the same property that makes `git log` — not the graph — the
authoritative answer to "where do I continue".

## 4. The delegation view: five defects, all mine, all in one feature

`Delegate` gained `dagr_plan` so the operator's plan can be named in conversation rather than
through a container-scoped variable that `.devcontainer`'s read-only mount put out of reach. It
took five goes, and the pattern is worth recording because it will recur: **each defect was found
by running it, never by a gate, because I wrote the code and its tests from the same assumptions.**

| | commit | what was wrong |
|---|---|---|
| 1 | `ee09e7b` | the schema's own example was a relative path; `path_within` is a lexical prefix test against an absolute workdir, so the documented value was refused as "outside the sandbox" while sitting inside it |
| 2 | `996dc77` | `plan_task_of` dropped `unblock`, so two `blocked` tasks failed `dagr check --strict` and **every publish that session was refused** — no run file at all, and the pane said only "waiting for run file" |
| 3 | `996dc77` | `projects` were not seeded, so 23 tasks under five projects would have rendered flat |
| 4 | `5f73d8f` | `check_wait_ms` was 20s, sized against a 30s wall that does not exist on this path (`session.ail:1115` hardcodes `timeout_ms: 0`; `ports.ail:544` says 0 means no deadline) |
| 5 | `fdfd34a` | a failed wait's message spent its width on a delegate handle, so a narrow pane showed `Waiting on delegat…` and nothing diagnosable |

It works now, verified on the real file: 5 projects, 23 tasks, `dagr check --strict` returns `[]`,
and a delegation attaches to `P1P6` with **zero** `mot-dlg-*` tasks opened beside it.

## 5. Open, in the order I would take them

1. **`ee09e7b`, `5f73d8f`, `996dc77`, `fdfd34a` have had no reviewer but me**, and the seeding path
   now decides whether the delegation view exists at all. `/code-review` over that range is cheap
   insurance and is the single highest-value thing outstanding.
2. **An unresolved discrepancy, deliberately not guessed at.** `herdr.ail:1586` returns
   `exit_code: 1`, yet the pane renders `DelegateCheck exit=0` on the same timestamp, with zero
   `exit=1` in 200 lines of scrollback. If the TUI shows the dispatch result rather than the
   envelope's code for extension-handled tools, then every `DelegateCheck` of that session was
   reported to the model as a failure while looking clean on screen. `fdfd34a` makes the next such
   line readable — `herdr exit N, code \`X\`, stderr M bytes` — and **one line of output settles
   it**: `stderr 0 bytes` means `bash_field` is not finding what the dispatcher writes; a non-zero
   count beside an unrecognised code means `wait_elapsed`'s vocabulary is short.
3. **P3 Part 3** is next in the plan: the emits, which turn Part 2's deliberate red green.
4. **The oh-my-pi observation, not yet written up.** omp waits on another herdr agent by
   BACKGROUNDING the blocking call — `⟨Backgrounded: bg_10⟩`, "waiting on 1 job" — so the wait
   costs no provider calls. ADR-002's Context already notes that Motoko's between-turn block costs
   no model call and that the two obstacles are the model cannot elect it and nothing wakes it but
   a human typing. `WorkInFlight` (7.3) has since answered the first. So a **host-side wake** — the
   TUI runs the wait and injects a synthetic `user_message` on completion — would remove most of
   the step burn at roughly D5-step-1 cost, with no `Park`, no `wake_read`, no cursor, no ABI
   change. It is a bridge and not a substitute: a host-injected message is a duration, not a
   transition, so it stays invisible to DST for exactly the reason v4.2 records. Also cheap and
   separate: omp fell back from `agent wait` to `herdr pane wait-output --match`, which does not
   depend on herdr classifying the agent at all — relevant given motoko's `idle` ambiguity that
   ADR-002 lists as not retracted.
5. `QCANARY` (the depth-canary re-measure) and `REV31` (PLAN-003 v3.1's six deltas, unreviewed) are
   still open in the graph and gate nothing.

## 6. Restarting the orchestrator

`max_steps` is 1200 (`9bfcc2f`) and `check_wait_ms` is 45s (`5f73d8f`), so a 20-minute delegate
costs ~27 checks rather than ~60. Do §2's memory work first.

The prompt that produced the working run, with the graph reconciliation it needs:

```
Continue implementing PLAN-003 from the dagr graph in .dagr/run-plan003.json.
Pass `dagr_plan: ".dagr/run-plan003.json"` on your first Delegate call and
`dagr_task` with the graph task id on every one. Read the plan; never write it
except as described under GRAPH below.

After your first Delegate, CHECK THE RESULT TEXT. If it says the plan was not
recorded, or that a plan in effect could not be read, or that `dagr_task` was
not linked, stop and report it — the delegation view is then wrong and every
later task will pile up beside the plan instead of on it.

WHERE TO CONTINUE — work it out, do not assume
- `git log --oneline` names the last part that landed. §0.5 gives each part
  exactly one commit naming it, written by the delegate as its last act, so it
  is true the moment the work finishes. This is the authoritative record.
- .dagr/run-plan003.json carries the plan's STRUCTURE — projects, deps, gates,
  criteria. Its task states lag: it froze at P3P1 when the last session was
  killed, and P3 Part 2 has since landed. Where they disagree, git is right.
- Reconcile first, then take the first task whose deps are satisfied and which
  git shows unlanded. Say which task you picked and why before delegating.

GRAPH
- After each part lands, settle its task in .dagr/run-plan003.json — edit a
  copy, `dagr check --strict --json`, `mv` — with the commit hash as the
  attempt receipt, matching the already-done tasks, and refresh generated_at.
  Do this BEFORE the next delegation, so a session that dies leaves a graph
  stale by at most one part and never by the part it was about to start.

HOW TO WORK
- One part per delegate, `kind: claude`. Parts 1-6 were implemented by claude
  delegates and it works; do not switch kinds without saying why.
- Before each brief, read that part's plan section IN FULL plus §0's standing
  rules, the governing ADR-003 v6.1 decisions, and the git log messages of the
  prior parts — those carry spec drift already resolved at HEAD, and the plan
  is grounded at 97827bf so its line numbers are stale. Tell each delegate to
  resolve stale references by reading the code and noting the drift, not by
  stopping to ask.
- Each delegate makes exactly ONE commit and does not push. You verify its gate
  before moving on.
- If a gate cannot be run, the delegate must say so and report what it did
  verify. A gate that could not run is not a gate that passed.

BUDGET
- 1200 steps; every DelegateCheck costs one and blocks 45s. Keep one delegation
  in flight and do nothing expensive between checks.
- At step ~1000, stop starting new parts: collect what is in flight, settle the
  graph, and write a handoff naming the last commit, the in-flight handles and
  the next task id.

Report after each part: the commit hash, the gate evidence, which gates could
not be run and why, and what the next part consumes.
```

## 7. Cross-references

- `PLAN-003-implement-adr-003.md` v3.1 — the plan; §0 standing rules, §5 results, §7 estimates.
- `ADR-002-park-and-wake.md` v4.2 — §10-adjacent reasoning for item 5.4 above; D5 sequencing.
- `../../issues/a-killed-motoko-process-exits-silently.md` — the OOM kill and the triage.
- `../021_herdr_delegation/PATCH-agent-confined-mem-limit.md` — the ceiling, and why 24g needs a
  32 GB VM.
- `../021_herdr_delegation/DESIGN-dagr-as-delegation-view.md` §10.5.1 — the second channel for A2
  and why the first was not enough.
