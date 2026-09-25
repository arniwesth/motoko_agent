---
repo: arniwesth/motoko_agent
pr: 171
branch: arniwesth/mot-113-record-the-first-autonomous-delegation-in-agent_confined
ticket: MOT-113
title: "MOT-113: record the first autonomous delegation in agent_confined"
---

## Summary

Records the first end-to-end run of the herdr delegation surface, in
`021_herdr_delegation/RESEARCH-…` as a new §8.

On 2026-08-22 a `claude` delegate was started in a pane inside `agent_confined`, handed a brief, and
left unsupervised to implement MOT-111 — write `tools/pr/linear.ts`, test it, commit, push, open PR
#170. It succeeded, and proved itself by attaching its own PR to its own Linear issue through the
code path it had just written.

Documentation only. The four findings below cost the design something, so they are recorded where
the design will be made from rather than left in a terminal.

Linear: [MOT-113](https://linear.app/motoko-agent/issue/MOT-113/record-the-first-autonomous-delegation-in-agent-confined-herdr-agent).
Related: [MOT-112](https://linear.app/motoko-agent/issue/MOT-112/r9-leg-4-checks-git-config-not-what-commits-actually-carry-and-never) (F-D's check gap), MOT-111 / #170 (the delegated work itself).

## Changes

- docs(021): record the first autonomous delegation, and what it cost

1 file changed.

## Governing docs

- `.agent/projects/021_herdr_delegation/RESEARCH-herdr-delegation-surface.md`

## Predicted outcome

§7 of that document lists what must be measured before designing. This closes two of its items and
makes a third worse, which is the point of recording it:

- **Item 2 answered.** It feared `agent start --kind claude` failing to detect in this image, "fatal
  to the whole design". Detection is fine — herdr registered the pane by itself. The failure is a
  first-run CLI prompt, and belongs in the image rather than the harness.
- **Item 6 gains its first data point** (~15 min). One sample is not a budget, said as such.
- **Item 3 becomes suspect, not merely open.** F-A shows the wait machinery losing a transition, and
  item 3 is very likely the same machinery.

Checked by: §4.1's design settling on polling rather than `agent wait`, and by the next delegation
not repeating F-B or F-D.

## Test evidence

The findings *are* the evidence; each is reproducible.

**F-A — `agent wait` misses a long transition.** A 45-minute wait launched while the agent was
`working` never fired when it went idle; it exited only when killed. Three controls against the same
agent all behaved correctly, which is what isolates it:

```
repeated --until idle --until blocked, already idle   -> returns at once, exit 0
single   --until idle,                 already idle   -> returns at once, exit 0
--until working (never entered), --timeout 5000       -> times out at 5.087s, exit 1
```

**F-B — `agent start` blocks on first-run prompts.**

```
{"error":{"code":"agent_not_ready","message":"agent mot-111 is blocked during startup ..."}}
```

Cause read directly off the pane: *"Try the new fullscreen renderer?"*. Cleared with
`herdr pane send-keys <pane> 2` then `enter`. `herdr agent list` had already registered the pane as
`claude` regardless.

**F-C — brief as pointer.** The 43-line brief was staged on disk and its path passed; sending it as
prompt text would have submitted on each newline.

**F-D — identity from history.** Read verbatim out of the delegate's scrollback:

```
git -c user.name="motoko-agent" -c user.email="<operator>" commit -q -F - <<'EOF'
```

immediately after it had run `git show --stat` and seen that author in the output. The two commits
were corrected afterwards (replayed with the bot identity, author dates preserved, tree byte-identical);
the check gap that let it through is MOT-112 and is still open.

No behaviour changes in this PR, so there is nothing to run.
