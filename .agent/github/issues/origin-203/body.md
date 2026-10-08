---
repo: arniwesth/motoko_agent
issue: 203
title: "ESC then resume fails when WORKDIR is outside the repo: the journal is outside the FS sandbox, the refusal says 'header', and the TUI hangs in thinking"
---

## Summary

The journal-based resume after ESC (ADR-003 D6 / PLAN-003 P3 Part 5) works when `WORKDIR` is the Motoko repo, but fails whenever `WORKDIR` is anywhere else. The TUI writes the journal under `<MOTOKO_REPO>/.motoko/sessions/<id>/`, but the `--resume` child runs with `AILANG_FS_SANDBOX=<workdir>`, so it cannot see the file. The fold refuses with a misleading `[header]` message, and the TUI then hangs in `state: thinking` with no runtime alive. The context from before ESC is lost, which is the #15 symptom again for any run whose workdir is not the repo (Motoko pointed at another repo, eval workspaces).

## Context

**Repro (main @ 0d5365a8, AILANG v0.47.2):**

1. `WORKDIR=/some/other/dir MODEL=openrouter/anthropic/claude-sonnet-4.6 ./scripts/run-agent.sh` (with `SYSTEM.md` copied into that dir and `SYSTEM_MD=SYSTEM.md`, otherwise the run stops earlier on "system prompt required but system prefix is 0 chars").
2. Prompt: ``The secret codeword for this session is PELICAN-7342. Step 1: run the shell command `sleep 90 && echo done` using your bash tool. Step 2: after it finishes, reply with the codeword.``
3. Press ESC while `BashExec sleep 90` is running. The TUI prints `Task interrupted` / `Your next prompt resumes this session from its journal.`
4. Prompt: `What was the secret codeword I gave you earlier in this session? Answer from memory without using any tools.`

**Observed:**

```
Resume refused (header): [header] the first entry on the path is not a `header`; D4 rule 1 makes the header the root of
every resumable path, and a path that starts anywhere else is a path through a file this fold did not write The next prompt starts a fresh
run in this session.

[λ] | state: thinking | step 0 | ...
```

The follow-up is never answered. The status bar stays `thinking` indefinitely (watched for more than 6 minutes), with no `ailang run` child alive. The session dir gets an `unresumable` marker.

**Control:** same steps with `WORKDIR=<repo>` resume correctly: `resumed session #1 · last boundary: exit (abort) · stripped 1 dangling tool call(s)`, and the model answers `PELICAN-7342`.

**The journal is not malformed.** It has 7 entries: `header` (seq 0, `parent_id: null`), `run_started`, three `history_appended`, `state_delta`, `exit {reason: "abort", pending_tool_calls: [...]}`, all correctly chained.

**Root cause (verified):**

- `src/tui/src/session-journal.ts:213` puts the journal at `path.join(projectRoot, ".motoko", "sessions", sessionId)`, which is the repo, not the workdir.
- `src/tui/src/runtime-process.ts:475` spawns the child with `AILANG_FS_SANDBOX: workdir`.
- `src/core/rpc.ail:545`: `if not fileExists(path) then refuse_resume(path, Header)`. Under the sandbox, `fileExists` is false for a path outside the workdir, so a missing or unreadable file is reported as a `Header` refusal.
- A standalone probe confirms it: `fileExists("<repo>/.motoko/sessions/<id>/journal.jsonl")` returns `EXISTS` without the sandbox and `MISSING` with `AILANG_FS_SANDBOX=<other dir>`.

This is the same class of problem as #196 (model catalogue) and the profile mirror (`mirrorProfileFromRepo`): a repo-rooted path read from inside a workdir sandbox.

**Secondary observations from the same run:**

- After a refusal, `index.ts` marks the session unresumable and sets `errorOccurred`, but the prompt that triggered the resume is not re-run as a fresh task, and the UI is left in `thinking` instead of returning to awaiting a task.
- After ESC, the killed runtime's `bash -lc sleep 90 && echo done` child kept running until it finished on its own.

## Expected

- With `WORKDIR` outside the repo, ESC followed by a follow-up prompt resumes from the journal and the model can recall pre-interrupt context. This can be checked with the repro above: the answer contains `PELICAN-7342`. Options: keep the journal under `<workdir>/.motoko/sessions/`, mirror or pass it into the sandbox, or have the host read it and pass it over stdin.
- A journal the child cannot see is reported as missing or unreadable, not as `[header]`.
- When a resume is refused, the TUI either runs the pending prompt as a fresh run or returns to awaiting a task. It never stays in `thinking` with no child.
