# PLAN-004 P1.1R — review of the `PortedWorld` variant commit

Date: 2026-09-16. HEAD: `65003110ff5a15e2ae5b1f0e205e0ffa705d18dc` (`git rev-parse HEAD`), which **is** the
subject commit. Branch: `arniwesth/013-plan003-and-herdr`.
Subject: `6500311` "ADR-004 D2: the PortedWorld test-provider variant, line-neutral", parent `8f70d33`.
Delegate task: `mot-dlg-1789580928153`. Graph task: `P1.1R` (reviewing `P1.1·a1`).

**Reviewer: claude (Claude Opus 5), not Codex.** Codex is not permitted in this container. The graph's
`P1.1R` note allows this ("Codex if available, else claude, stated"), and the file is named `-claude-` so the
provenance stays accurate.

**Inputs, read in full:** PLAN-004 v2.1 §0 items 1–5 (with §0.7, §0.8 and §0.10 for the commit and review
rules) and §3 P1.1 / P1.1R → P1.1G; ADR-004 v5 D2 (`:754–830`) and D5's "The variant commit" (`:1244–1247`);
`REVIEW-adr004-v5-verdicts-claude.md` §3.9; the P1.1 and SWEEP rows in `.dagr/run-plan004-v2.json`; the
commit's diff and message.

**Method:**

- Git checks: `git show --stat`, `git diff --unified=0`, `wc -l` and the bridge-span `sha256sum` at both
  commits and in the working tree.
- `ailang check` on the three edited files, plus `scripted_ports.ail`.
- The four make targets the brief allows.
- A search for every `StepProvider` match site and every caller.
- The author's mutations, plus one more (M3), run on throwaway copies of the committed tree. The copies
  were made with `git archive 65003110 src scripts packages ailang.toml ailang.lock` into the session
  scratchpad, so the repository was never touched.
- A 15-line scratch program to check how AILANG handles a match with a missing arm.

**What I did not do:**

- No `make dst`, replay, profiling or other heavy run.
- No edit to any file except this document, and no commit.
- No herdr pane touched and no `.dagr` file edited.
- No corpus content read.
- No `make` run inside the mutation copies: I ran the wire script `scripts/dst/run_ledger_parity_wire.sh`
  directly, and `make` turns its exit 1 into exit 2.

Two things were already running and I left them alone: two live `supervisor.ail` sessions. `memory.current`
was 6.1 GiB at the start.

**Evidence** is in `/tmp/claude-1001/-workspaces-motoko-agent/ae2a39d7-d028-4f4f-88af-cbc5129bc933/scratchpad/`:
`anchors.txt`, `dli.txt`, `lp.txt`, `sr.txt`, `chk_*.txt`, `m0.txt`, `m1.txt`, `m3.txt`, `m1_lp*.txt`,
`m0_lp.txt`, `m3_lp.txt`, `exh/exh.ail`, and the copies `mut_M0/`, `mut_M1/`, `mut_M3/`.

---

## Verdict — ACCEPT WITH CORRECTIONS

The commit is exactly the five planned joins. It is line-neutral, the bridge span is byte-identical, every
anchor pin holds without a re-baseline, the edited files type-check, and all four harness gates are green.
Every gate figure in the commit message reproduces.

None of the corrections needs a change to the code, and none needs a second round. They are record and
plan changes that the orchestrator applies when it settles `P1.1·a1` (§0.10 (a)3):

- **C1 (receipt).** Record that **joins 3 and 5 are both inert under type-checking and untested**. The
  commit reports only join 5 (M0). This review shows that removing join 3 alone (M3) is also undetected:
  `ailang check session.ail` exits 0 and the ledger_parity wire gate passes. The receipt should say
  "arms 3 and 5 unexercised until a `PortedWorld` is constructed".
- **C2 (PLAN-004 §3 P1.5, forward obligation).** P1.5 (or P1.6, whichever first runs `PortedWorld`) must:
  - build a `PortedWorld(p, w)` and drive it through a caller of `ported_provider`;
  - assert something that tells `world: w` apart from `empty_world_state()`, e.g. that the run uses `w`'s
    script or ordinal;
  - assert something that tells `ports: p` apart from another adapter set, e.g. that a seam in `p` is hit.

  A **missing** arm already fails closed at runtime (item 5), but a **wrong** arm (for example
  `{ ports: p, world: empty_world_state() }`) would not, so P1.5's test must be the one to catch it. Join 5
  (`frame_ordinal0`) is only reached when `ledger_parity_dst` frames its own providers. It stays untested
  unless a `PortedWorld` frame is added there, and this should be recorded as accepted non-coverage,
  alongside `scripted_ports.ail:30–35`.
- **C3 (wording, commit record and graph note).** "Post-variant source is the D5 basis for A" says more
  than the ADR does. ADR-004 D5 (`:1246–1247`) says the variant commit "lands before A and is inside A's
  protected basis by construction". Use that wording in the receipt and in the `P1.1` graph note.

**P1.1 may stand with arms 3 and 5 untested until P1.5.** Four reasons:

1. §0.8 credits no test ordering that lacks a recorded failure, and the commit claims none for these arms.
   It says openly that they are unexercised (M0).
2. The arms are additive. Nothing in the tree constructs `PortedWorld` (item 5), so no run that happens
   today can reach them.
3. AILANG fails closed on a missing arm at runtime ("no pattern matched in match expression", exit 1).
   An omission therefore cannot pass silently once P1.5 builds the variant.
4. The part of P1.1 that can be tested now — the variant and its imports (joins 1, 2 and 4) — is covered
   by M1.

The one residual risk is a wrong arm body. C2 assigns that risk to P1.5 instead of reopening P1.1.

---

## Per-item findings

### 1. The diff is exactly the five joins — ACCEPT

`git show 65003110 --stat`: `scripts/dst/ledger_parity_dst.ail | 4 ++--`, `src/core/session.ail | 4 ++--`,
`src/core/test/stub_step.ail | 2 +-`; 3 files, 5 insertions, 5 deletions.

In `git diff 8f70d33 65003110 --unified=0`, the content lines (with the `+++`/`---` headers removed) number
**5 `-` and 5 `+`**. The hunk headers are:

| hunk | change |
|---|---|
| `stub_step.ail @@ -69 +69 @@` | `\| PortedWorld(Ports, WorldState)` added after `Ported(Ports)`, **before** the trailing `-- GeneratedWorld: …` comment |
| `session.ail @@ -195 +195 @@` | `PortedWorld` added after `Ported` in the one-line constructor import |
| `session.ail @@ -1545 +1545 @@` | `, PortedWorld(p, w) => { ports: p, world: w }` appended after the `GeneratedWorld` arm. `func ported_provider` is at `:1532`, and `}` still closes the match at `:1546` |
| `ledger_parity_dst.ail @@ -73 +73 @@` | `PortedWorld,` added after `Ported,` |
| `ledger_parity_dst.ail @@ -435 +435 @@` | `, PortedWorld(_, w) => w.ordinal` appended after the `Ported` arm, inside `frame_ordinal0` (`:428`) |

These match PLAN-004 §3 P1.1's table and ADR-004 D2 (`:785–791`) text for text.

Nothing else changed:

- `git diff --quiet 8f70d33 65003110 -- tools/ Makefile` exits 0.
- `git diff 65003110 --stat -- src scripts Makefile tools` is empty.
- The working tree's only untracked files under `scripts/` are `scripts/dst/mem_canonical_bench.ail` and
  `mem_growth_probe.ail`, which predate this task (they appear in the session's opening git status) and are
  not part of the commit.

### 2. Line counts, bridge span and anchors — ACCEPT

**Line counts** (`git show <c>:<f> | wc -l`) are the same at both commits and in the working tree:

| file | `8f70d33` | `65003110` | working tree |
|---|---|---|---|
| `stub_step.ail` | 915 | 915 | 915 |
| `session.ail` | 6320 | 6320 | 6320 |
| `ledger_parity_dst.ail` | 642 | 642 | 642 |

**Bridge span.** `sed -n 1085,1474p src/core/session.ail | sha256sum` gives
`c074cefb5fdc508f4a0d884e21e0461c881e959fec8ef683243871c32260d262` at `8f70d33`, at `65003110` and in the
working tree. This matches the commit's `c074cefb…d262`. Neither `:195` nor `:1545` falls in 1085–1474,
which agrees with the v5 review §3.9.

**`make anchors`** exits **0**, with 10 ✓ and 0 ✗, and no file under `tools/` changed. The output includes:

- `✓ src/core/test/stub_step.ail:203 still the one remaining ambient clock (declared UNROUTED core)`
- `✓` at `session.ail` 1471, 1730, 1842, 4302 and 4523
- `✓ tool_phase.ail:484`
- the three attribution pins `ext/runtime.ail:199`, `tool_phase.ail:388` and `:389`

§0.3 lists only seven of these pins. `anchors.sh` checks ten, and **all ten** hold. `stub_step.ail:203`
still reads `{ now_ms: now(), next_state: state }`.

### 3. Type-check — ACCEPT

`ailang check` (AILANG v0.33.0) returns exit 0 and "✓ No errors found!" for each of the following:

- `src/core/test/stub_step.ail`
- `src/core/session.ail`
- `scripts/dst/ledger_parity_dst.ail`
- `src/core/test/scripted_ports.ail`, which was not edited; I checked it because it matches on the
  extended sum

**Environment note.** The working tree has an uncommitted `ailang.lock`. Its `generated_at` changed, and so
did the `content_hash` for `sunholo/logging`. The lock is not part of the commit, and the committed tree
(committed lock and packages, in the `git archive` copies) also type-checks: `ledger_parity_dst.ail`
exits 0 in the unmutated copy. The verdict therefore does not depend on that change.

### 4. Harness gates — ACCEPT

All four were run at HEAD `65003110`, one after another, starting 17:50:27Z:

| command | exit | closing output |
|---|---|---|
| `make driver_leaf_inventory` | 0 | `RequestClass frozen: EnvRead, FileRead, ClockRead, ToolExec, ModelStep, WakeRead`; by class EnvRead=13, FileRead=3, ClockRead=5, ToolExec=2, ModelStep=1, WakeRead=2; 8 aggregate helpers; 10 exempt ExtPorts fields |
| `make ledger_parity` | 0 | `ledger_parity wire gate PASS`; witnessed=25; "the fixture witnesses at least 17 required variants on both channels"; `WorldRequest: projected 175, returned 175` |
| `make strict_replay` | 0 | `strict_replay_dst PASS`; "discovery and replay agree with the driver's own wire emissions (provider=10, tool=4 over the pair)"; codec round trips ✓; about 29 s |
| `make anchors` | 0 | see item 2 |

**ADR-001 D6 precondition.** The `SWEEP` row in `run-plan004-v2.json` is `done`: `SWEEP·a1`,
17:21:30Z–17:39:40Z, `make dst DST_JOBS=1` at HEAD `8f70d33`, exit 0, 51/51 targets passed, and it settled
before `P1.1·a1` started (17:41:30Z). The precondition holds. The commit's reference to "the SWEEP record in
the plan graph (not re-run)" is accurate.

### 5. Commit message: non-coverage, mutation record and M0 — ACCEPT (the M0 question is answered by C1 and C2)

**Non-coverage.** The message says that `src/core/test/scripted_ports.ail:30–35`
(`state_from_step_provider`) is left untouched and is a three-arm match over `Scripted`, `LiveAI` and
`Ported`. That is true: `:30` is the function, and `:32–34` are its three arms. The only caller is its own
test (`scripted_ports.ail:173`, which passes `Scripted(…)`), so the non-coverage cannot be reached from any
harness path. That fact is worth adding to the record.

**Red-first / mutation record.** The message says red-first does not apply and records M1 and M0 instead.
Both reproduce on copies of the committed tree:

| mutation | command | result |
|---|---|---|
| **M1**: join 1 removed, joins 2–5 kept | `ailang check scripts/dst/ledger_parity_dst.ail` | exit 1 |
| | `ailang check src/core/session.ail` | exit 1, `IMP010: symbol 'PortedWorld' not exported by 'src/core/test/stub_step'` |
| | wire script | exit 1 ("the in-process census failed (exit 1)"); `make` reports this as exit 2, which matches the commit's figure |
| **M0**: join 5's arm removed | `ailang check ledger_parity_dst.ail` | exit 0 |
| | wire script | exit 0 (`ledger_parity wire gate PASS`) — **not caught**, as the author reported |
| **M3** (this review): join 3's arm removed | `ailang check src/core/session.ail` | exit 0 |
| | wire script | exit 0 — **not caught either** (C1) |

In a copy with joins 3 and 5 both removed, `session.ail` also still type-checks (exit 0).

**Why M0 and M3 are not caught.** A search of `src` and `scripts` finds `PortedWorld` only at the five
joined lines. No expression anywhere constructs the variant. The scratch program `exh/exh.ail` (a
three-constructor sum, a two-arm match, and a call on the missing constructor) shows how AILANG v0.33.0
treats a missing arm:

- `ailang check` → exit 0. There is no exhaustiveness diagnostic.
- `ailang run` → prints the covered result, then `Error: execution failed: no pattern matched in match
  expression`, exit 1.

So the commit's statement "The type checker reports no non-exhaustive match" is correct, and a missing arm
fails **closed** the first time it is reached. The judgement on whether P1.1 may stand is in the Verdict
above.

A gap in the type checker could be sent to AILANG through `ailang-feedback`, but no exhaustiveness checking
is a known property here: `state_from_step_provider` has been a three-of-seven match for several variants.
This review does not require that feedback to be filed.

### 6. Factual accuracy of the commit and its message — ACCEPT WITH CORRECTION C3

Every checkable statement in the message is correct:

- the five joins and where each sits;
- the base `8f70d33`;
- "no line added or removed";
- the `wc -l` figures;
- the 5/5 content lines and hunk addresses;
- the `c074cefb…d262` hash;
- `ailang check` 0/0/0;
- `make anchors` 0 with `stub_step.ail:203`, and no re-baseline;
- `make driver_leaf_inventory`, `make ledger_parity` and `make strict_replay` all 0;
- M1's exits and IMP010 text;
- M0's exits;
- `scripted_ports.ail:30–35` described as legacy and non-covering.

The title matches §3 P1.1's required commit name exactly, and the `Co-Authored-By` trailer is present.

Imprecisions, none of which blocks the verdict:

- **"Post-variant source is the D5 basis for A"** → C3.
- **"the joins are additive, so red-first does not apply."** A failing test could in fact have been
  written first: any expression that constructs `PortedWorld` fails with IMP010 or an unknown constructor
  before join 1 exists. The real reason is that P1.1's scope has no test that constructs the variant. This
  does not change the verdict, because §0.8 allows a mutation check in place of red-first, and M1 is one.
- **M0 names only join 5.** The next sentence ("the arms are only exercised once P1.5 …") covers both arms,
  but the recorded mutation does not. Join 3 has the same status → C1.

---

## Claim audit

| # | Claim (source) | Status | Evidence |
|---|---|---|---|
| 1 | HEAD is `65003110…` (brief) | true | `git rev-parse HEAD` |
| 2 | Only the three files changed (brief, commit) | true | `--stat`; `tools/`, `Makefile` diff empty |
| 3 | Exactly 5 `-` / 5 `+` at @69, @195, @1545, @73, @435 | true | `--unified=0` count and hunk headers |
| 4 | `ported_provider` starts at `:1532`; the `GeneratedWorld` arm is at `:1545` (plan, ADR D2) | true | `session.ail:1532`, `:1545`, `}` at `:1546` |
| 5 | `frame_ordinal0` at `:428`, `Ported` arm at `:435` (ADR D2 `:428–435`) | true | `ledger_parity_dst.ail:428`, `:435` |
| 6 | Line counts 915 / 6320 / 642 unchanged | true | `wc -l` at both commits and in the tree |
| 7 | Bridge span sha256 `c074cefb…d262` before and after | true | full digest in item 2 |
| 8 | Every anchors.sh pin holds, incl. `stub_step.ail:203`; no re-baseline | true | `make anchors` 0, 10 ✓; `tools/` unchanged |
| 9 | `ailang check` 0/0/0 on the edited files | true | item 3 |
| 10 | `driver_leaf_inventory`, `ledger_parity`, `strict_replay` green | true | item 4 |
| 11 | SWEEP precondition met (ADR-001 D6, §0.1) | true | `SWEEP·a1` done at `8f70d33`, exit 0, 51/51, before `P1.1·a1` started |
| 12 | `scripted_ports.ail:30–35` is a three-arm legacy match that leaves world-bearing providers uncovered | true; unreachable from the harness | `:30–35`; only caller is `:173` |
| 13 | M1: IMP010 exit 1 on both checks; `make ledger_parity` exit 2 | true (wire script exit 1 → make exit 2) | item 5 |
| 14 | M0: removing join 5 is undetected | true | item 5 |
| 15 | (implicit) join 3 is covered | **not shown**; M3 undetected | C1 |
| 16 | "The type checker reports no non-exhaustive match" | true; runtime fails closed | `exh/exh.ail` |
| 17 | "red-first does not apply" because the joins are additive | imprecise; the mutation check is allowed instead (§0.8) | item 6 |
| 18 | "Post-variant source is the D5 basis for A" | imprecise → "inside A's protected basis" (ADR D5 `:1246–1247`) | C3 |
| 19 | Nothing that runs today constructs or reaches `PortedWorld` (ADR D2) | true | `PortedWorld` appears only at the five joins |
| 20 | Commit title matches §3 P1.1's required title | true | `git show -s` |

`P1.1G` may pass once `P1.1·a1` settles `done` with a receipt that names this document, its SHA-256 and the
applied corrections C1–C3, where C2 is a text addition to PLAN-004 §3 P1.5.
