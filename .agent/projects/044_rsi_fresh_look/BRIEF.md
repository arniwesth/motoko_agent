# BRIEF — a fresh look at recursive self-improvement in Motoko

Date: 2026-11-20. Repository HEAD: `2eae0666` (origin/main).
Moderator: Claude Opus 5.5 (herdr pane `w4:p5`). Participants: `fable` (Claude Code, Fable 5.2),
`astra` (Codex, GPT-6.2-Astra), `neon` (Antigravity, Gemini 4 Neon).

You are one of three participants in a bounded, moderated discussion. The moderator sends every
prompt and reads every turn. You never talk to the other participants directly.

## The question

> Given Motoko as it is today, what is the shortest credible path to recursive self-improvement,
> meaning Motoko improving the process by which it finds and accepts its own improvements? Name
> the first closed loop, the evaluator the improved component cannot influence, the first
> experiment with its pass/fail criterion, and what would make the loop keep compounding instead
> of plateauing. You may conclude that the current DST-centred direction is the wrong one.

"Fresh look" is the point. Reason from what the code and the measurements show, not from what
earlier plans assumed.

## Where to read

Read the code in the clean worktree **`/workspaces/motoko_agent-rsi-fresh-look`** (HEAD
`2eae0666`). The shared checkout `/workspaces/motoko_agent` has uncommitted edits by other
sessions; use it only for gitignored things, such as the AILANG checkout at
`/workspaces/motoko_agent/ailang`.

A neutral index. It says where things are, not what to conclude:

- `README.md`, `SYSTEM.md`, `CONTRIBUTING.md`, `Makefile` (its targets are the operational surface),
  `CHANGELOG.md`, `git log`.
- `src/core/` — the runtime (`agent_loop_v2.ail`, `step_machine.ail`, `*_phase.ail`, `journal.ail`,
  `supervisor.ail`, `tool_*`) and the DST machinery (`dst_*.ail`). `src/eval/` — evaluation and
  journal tooling. `src/tui/` — the terminal UI.
- `packages/motoko-ext-*` — extensions (herdr delegation, compaction, skills, guards, MCP, …).
- `design_docs/implemented/` — implemented designs. `design_docs/planned/` — planned ones.
- `.agent/projects/NNN_*/` — numbered design records: ADRs, PLANs, HANDOFFs, MEASUREMENTS,
  FINDINGS, REVIEWs. `ls .agent/projects` for the list. MEASUREMENTS and FINDINGS files are where
  claims were tested.
- `papers/motoko-dst-report/`, `benchmarks/`, `evidence/`, `scripts/dst/`, `tools/`.

## Round-1 embargo (lifted in round 2)

In round 1, do **not** read these. They are the project's earlier plans for self-improvement, and
round 1 exists to get a view that is not anchored on them:

- `design_docs/planned/m-motoko-dst-recursive-self-improvement.md`
- `.agent/projects/014_comparative_self_evolution/`
- `.agent/projects/015_idea_factory/`
- `.agent/projects/032_dream_rsi/`
- `.agent/projects/042_improving_experimentation/`
- `docs/motoko-frontier-of-abstraction-*`, `docs/motoko-six-month-retrospective-*`,
  `docs/motoko-blogpost-handoff.md`

Many other files mention RSI in passing; reading them is fine. If you open a document and find its
main subject is a plan for Motoko's self-improvement, stop reading and name it in your turn.

## Rules

1. **Write exactly one file per turn**, at the path the moderator's prompt gives. Edit no other
   file anywhere. No commits, branch switches or worktree changes.
2. **Read only the discussion files the prompt names.** Do not open other files under
   `.agent/projects/044_rsi_fresh_look/discussion/` — the other participants may be writing there.
3. **Read-only commands only, each under about two minutes:** `grep`, `git log`, `git show`,
   `ailang check` on a single file, and similar. No `make dst`, no sweeps, no long builds.
4. **Do not use herdr** and do not prompt, open or close any pane or agent. Subagents inside your
   own harness are fine.
5. **Cite.** Every factual claim about Motoko carries `path:line`, a commit, or a command and its
   output. Mark anything you could not check `[unverified]`. Outside sources are welcome, with a
   reference; mark recall from memory as such.
6. **When done, reply with only the path of the file you wrote.**

## Rounds, and how the discussion ends

| Round | Task | Prose limit | Moderator timeout |
|---|---|---|---|
| R1 blind proposal | Answer the question independently, under the embargo | 1500 words | 40 min |
| R2 reveal & cross-examine | Read the others' R1 and the embargoed documents; attack, compare, revise | 900 words | 30 min (raised from 20 before R2 was sent: more to read) |
| R3 final position | Ranked proposals, one first experiment, remaining disagreements | 600 words | 20 min |
| Check | Flag only misstatements of your own position in the moderator's synthesis | 200 words | 10 min |

- There is no round 4. After R3 the moderator writes the synthesis.
- **Early stop:** if after R2 every participant reports `position_changed: no` and lists no
  material disagreement, R3 is skipped.
- A missed turn is retried once, then recorded as missing.
- Disagreements still open after R3 are recorded for the human to decide. They are not argued
  further.

## Turn format

Markdown. A header line `# <participant> — round <N>`, the prose (word limit above; citations,
code excerpts and the YAML block do not count), then this block, last in the file:

```yaml
participant: fable | astra | neon
round: 1 | 2 | 3
position_changed: n/a | yes | no        # n/a in round 1
top_proposals:                          # at most 3, ranked
  - id: P1
    title: ""
    one_line: ""
first_experiment:
  what: ""
  pass_if: ""                           # stated before the experiment runs
  fail_if: ""
  cost: ""                              # build effort and compute, rough
disagreements:                          # empty in round 1
  - with: fable | astra | neon | prior-docs
    about: ""
    material: yes | no                  # would it change what gets built first?
would_change_my_mind_if: ""
embargo_notes: ""                       # round 1: anything you opened and stopped reading
```
