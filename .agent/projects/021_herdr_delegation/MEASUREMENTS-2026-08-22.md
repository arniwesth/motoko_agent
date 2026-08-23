# MEASUREMENTS: 021 §7, taken against a running herdr

Date: 2026-08-22
Taken by: the session implementing `HANDOFF-implement-motoko-ext-herdr.md` (Phase A)
Where: inside `agent_confined` (container `ab3ed0fab4f6`), in herdr pane `w1:p7`, workspace `w1`
Against: **herdr 0.8.2**, `claude` 2.1.240 (Claude Code), `codex-cli` 0.149.0
Subject: the six items 021 §7 owes. **Phase B must not be built against 021 where this file
contradicts it** — 021 was written from documentation, before anything had met a server.

Everything below marked *measured* was executed. Anything inferred is labelled as such.

**Provenance note.** Parts 1 and 2 were taken on two different days against two different container
states. On **2026-08-22** `codex` had no credentials, so its halves of M1, M2, M5 and M6 could not be
taken. The operator authenticated `codex` (ChatGPT OAuth) on **2026-08-23**, and **Part 2** below
takes them. Where a §7 item has both halves, the verdict table reflects the combined result and the
per-item section points to Part 2.

---

## Verdicts at a glance

| # | 021 §7 question | verdict |
|---|---|---|
| 1 | Does `pane split --env KEY=` read as *absent* to the CLIs? | **Yes, for both — and neither CLI silently prefers an env key at all.** 018 F2's feared billing inversion does not exist here. See M1 + P2-1. |
| 2 | Does `agent start --kind codex\|claude` reliably detect in this image? | **Both: yes, on a real rule match**, once authenticated. See M2 + P2-2. |
| 3 | What does `agent prompt --wait` do on a slow start? | **`agent_prompt_stalled` at 5.0 s — but only on a *false-ready* agent, never on a genuinely ready one (0/8).** 021's worry is unfounded; the stall is a useful fail-fast. See M3. |
| 4 | Does herdr's argv trip `shell_tokens_in_process`? | **Only `agent prompt` does, and it does so routinely. 021's proposed escape does not exist in v0.8.2.** A different escape does, and is validated. See M4. |
| 5 | Do delegates comply with "write your answer to `<path>`"? | **`claude`: 4/4. `codex`: complies when attended, but *replies with the path without writing the file* when not.** See M5 + P2-3. |
| 6 | Realistic wall-clock and answer size? | **median ≈ 23.1 s, worst case 91.2 s, 50 % of realistic tasks exceed 25 s** (`claude`); `codex` runs 27.6 s unattended on the identical task. §4.1's optimistic-synchronous default is wrong. See M6 + P2-4. |

**The three results that change the design:** M6 (poll-first, not optimistic-synchronous), M4 (the
model-authored prompt must travel in a file, because it cannot travel in argv), and **P2-3** (a
delegate's reply naming the answer path is *not* evidence the file exists — verify it).

---

## M1 — `pane split --env KEY=` semantics, and the billing guard

**Measured, mechanically.** A pane was split with
`--env ANTHROPIC_API_KEY= --env OPENAI_API_KEY= --env MOT_PROBE_SET=hello --env MOT_PROBE_EMPTY=`
and the pane shell's `/proc/<pid>/environ` read directly:

```
ANTHROPIC_API_KEY=        <- PRESENT, value length 0
OPENAI_API_KEY=           <- PRESENT, value length 0
MOT_PROBE_EMPTY=          <- PRESENT, value length 0
MOT_PROBE_SET=hello       <- PRESENT, value "hello"
```

`--env KEY=` **sets the variable to the empty string. It does not unset it.** Exactly the documented
"adds or replaces" semantics, and exactly what 021 §3.5 flagged as the open question.

**Does empty read as absent?** For `claude`, **yes**: a delegate started in that pane answered a
prompt normally in 2.4 s, using the on-disk OAuth credential. Empty did not break credential
resolution and did not select a key path.

**Does a *non-empty* env key override the subscription credential?** This is the half 018 §5.1 never
measured, and the answer is **neither yes nor no — `claude` asks.** A pane split with
`--env ANTHROPIC_API_KEY=sk-ant-api03-INVALIDKEYFORTEST0000000000` produced, at startup:

```
  Detected a custom API key in your environment
  ANTHROPIC_API_KEY: sk-ant-...KEYFORTEST0000000000
  Do you want to use this API key?
    1. Yes
  > 2. No (recommended)
  Enter to confirm · Esc to cancel
```

**Consequences, and they are not the ones 018 expected.**

- The silent-billing-inversion risk that drove 018 F2 **does not exist for `claude` 2.1.240** — an
  inherited key cannot bill the wrong account without someone answering a modal.
- But the failure it *does* cause is worse for an unattended delegate: the agent **hangs on a modal
  at startup**, and herdr reports it as `idle` / `interactive_ready: true` (see M2). A `Delegate`
  that trusted `agent start` would prompt a login dialog.
- So `--env ANTHROPIC_API_KEY=` is a **real and necessary guard**, not a cosmetic one — it is what
  stops the modal from appearing at all. 021 §3.5 asked whether this was "a fix or a decoration".
  It is a fix, for a different failure than the one it was proposed against.
- **Recommendation for Phase B:** always split with `--env ANTHROPIC_API_KEY= --env OPENAI_API_KEY=`.
  Cost is zero, and it removes a whole class of startup hang.

**`codex`: measured on 2026-08-23, see P2-1.** Short version: `codex` **silently ignores** a
non-empty `OPENAI_API_KEY` when stored ChatGPT auth is present, and treats `--env OPENAI_API_KEY=`
as absent. So neither CLI exhibits 018 F2's feared silent billing inversion.

**Baseline for the record:** in `agent_confined` today, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` and
`GOOGLE_API_KEY` are all **present but empty**; `OPENROUTER_API_KEY` (73 chars) and `EXA_API_KEY`
(36 chars) are set.

---

## M2 — does `agent start --kind claude|codex` detect?

**`claude`: yes, and on a genuine screen-rule match.** Three starts, 3850 / 3919 / 3946 ms — call it
**~3.9 s, consistently**. `agent explain` returns a real rule:

```
agent: claude / state: idle / manifest: bundled 2026.08.13.1
rule: live_prompt_box (region=prompt_box_body priority=950) / evidence: "❯\n"
```

The started agent is addressable **by name as well as by pane id** (`agent get dlg-claude-a` works),
which is the difference from the *reported* agent in the 020 briefing §4.1. `pane process-info`
confirms `argv: ["claude"]`.

**`codex`: detected, but not usable, and the detection is weak.** `agent start --kind codex`
succeeded in 3.9 s and reported `agent_status: idle`, `interactive_ready: true` — but the pane was
sitting on a sign-in menu:

```
  Welcome to Codex, OpenAI's command-line coding agent
  Sign in with ChatGPT to use Codex as part of your paid plan
  > 1. Sign in with ChatGPT   2. Sign in with Device Code   3. Provide your own API key
```

and `agent explain` shows **no rule matched at all**:

```
agent: codex / state: idle / manifest: bundled 2026.08.09.1
rule: none / fallback_reason: default_known_agent_idle_fallback
```

### The finding that matters more than the question asked: herdr's "ready" is not "usable"

`interactive_ready: true` was returned for **both** broken cases measured — the unauthenticated
codex, and the `claude` stuck on the API-key modal. In both, `agent explain` gave the same tell:

> `matched_rule: null` and `fallback_reason: "default_known_agent_idle_fallback"`

…meaning herdr never actually matched a live agent prompt; it defaulted to `idle` because argv said
a known agent was running. A healthy delegate has `matched_rule` populated and `fallback_reason:
null`.

**This is machine-readable.** `herdr agent explain <pane> --json` emits (top level, no `{"id",
"result"}` envelope):

```json
{"agent":"claude","state":"idle","manifest_source":"bundled","manifest_version":"2026.08.13.1",
 "matched_rule":{"id":"live_prompt_box","priority":950,"region":"prompt_box_body","state":"idle"},
 "fallback_reason":null,"visible_idle":true,"visible_working":false,"visible_blocker":false,
 "screen_detection_skipped":false,"warning":null, "evaluated_rules":[...]}
```

**Recommendation for Phase B (new, not in 021):** after `agent start` and *before* the first prompt,
call `agent explain --json` and require `matched_rule != null && fallback_reason == null`. It costs
one ~5 ms call and it is the difference between delegating and typing into a login screen.

**This is not a theoretical hazard — it was demonstrated.** Prompting the false-ready codex pressed
Enter on its sign-in menu and **started an OAuth device-authorisation flow** (the pane filled with a
`code_challenge=…&originator=codex-tui` URL). A `Delegate` without this gate will do that.

**Verdict against the handoff's *Stop and report* trigger:** §7 item 2 has **not** failed. Detection
works for both kinds — and once `codex` was authenticated (2026-08-23) it too matched a real rule
(`osc_title_idle`), confirming that the `matched_rule`/`fallback_reason` gate discriminates
authenticated from broken agents rather than merely distinguishing the two CLIs. See P2-2.

Phase B should still default to `--kind claude`, for the reason in P2-5: `codex` cannot run
unattended in this container.

---

## M3 — `agent prompt --wait` on a slow start

**Measured.** `agent_prompt_stalled` is real, fires at **5.04 s**, exits 1, and carries a precise
message:

```json
{"error":{"code":"agent_prompt_stalled",
  "message":"agent prompt produced no observed state change within 5000 ms; status is idle and state_change_seq remained 48"},
 "id":"cli:agent:prompt"}
```

**But 021 §7 item 3's worry is unfounded.** It feared "a delegate that thinks before printing could
trip it routinely, which would make the optimistic path the wrong default". Across **eight** prompts
to genuinely-ready `claude` delegates, `agent_prompt_stalled` fired **zero times** — Claude Code
transitions to `working` within milliseconds of submission, long inside the 5 s window.

The one time it fired was against the **false-ready codex** of M2. So in practice:

> `agent_prompt_stalled` is not a slow-thinking signal. It is a **broken-delegate signal**, and a
> cheap one — 5 s to fail fast, well inside Motoko's 30 s process wall.

That makes it a good thing to keep, and a second line of defence behind M2's `explain` gate.

### `--timeout` semantics, measured, because they are not what §3.1 assumed

| call | wall clock | outcome |
|---|---|---|
| `--wait --timeout 5000`, task needing ~6 s | **5 103 ms** | `{"error":{"code":"timeout","message":"timed out waiting for agent status"}}`, exit 1 |
| `--wait --timeout 25000`, task needing ~25.07 s | **25 051 ms** | `timeout`, exit 1 — missed by 21 ms |
| `--wait --timeout 25000`, task needing ~28.3 s | **28 334 ms** | returned `done`, **overran the bound by 3.3 s** |

So the bound is *usually* tight (5.10 s and 25.05 s are within 100 ms), but **one of three trials
overran it by 3.3 s**, returning success rather than `timeout`. Submission itself is not the cause:
`agent prompt` without `--wait` returns in **3–5 ms**.

**Consequence:** `--timeout T` cannot be treated as a hard wall-clock guarantee. Under a 30 s
`std/process.exec` wall, a `--timeout 25000` call has been observed to take 28.3 s, leaving 1.7 s of
margin. This is a second, independent reason not to put `--wait` on the critical path (M6 is the
first).

**And a timeout does not cancel the delegate.** After the 5 s `timeout` above, the delegate finished
its turn ~1 s later and produced the correct answer. `--wait` timing out means *still working* —
which is exactly the reframing 021 §3.1 predicted, now measured.

---

## M4 — does herdr's argv trip `shell_tokens_in_process`?

**Measured against the source** (`src/core/tool_runtime.ail:50` for the test, `:888-894` for the
wrap) and evaluated over the real argv sets this design needs. `has_shell_tokens` matches eight
tokens: `|` `>` `<` `&&` `||` `;` `$(` `` ` ``; the test also fires when `req.cmd` is a shell or
contains a space, and the wrap is additionally entered whenever `req.cwd` is `Some`.

| herdr call (cmd = `/usr/local/bin/herdr`, `req.cwd = None`) | verdict |
|---|---|
| `pane split --current --direction down --cwd <repo> --no-focus --env ANTHROPIC_API_KEY=` | safe |
| `agent start <name> --kind claude --pane <id> --timeout 20000` | safe |
| `agent get <target>` / `agent list` / `agent explain <target> --json` / `pane close <id>` | safe |
| `agent read <target> --source recent-unwrapped --lines 200` | safe |
| `agent prompt <target> "<fixed wrapper sentence naming two paths>" --wait --timeout 20000` | **safe** |
| `agent prompt <target> "<model-authored text>" --wait --timeout 20000` | **TRIPS** |

The single tripping case is the one that matters: model-authored prompts carry backticks, `>`, `;`
and `&&` as a matter of course. Example that trips —
``Refactor `parse_config` so it returns Result<Config, Error>; run `make test && make lint` …``

**What tripping actually does here, measured.** The wrap rebuilds the command from `req.cmd` alone
and runs `bash -lc "/usr/local/bin/herdr"`. Inside a herdr pane that is **not** "prints help" — it
hits a nested-herdr guard:

```
error: nested herdr is disabled by default.
see configuration if you want to enable it.
"recursion detected. base case not found. aborting."
```

exit 1, ANSI-coloured **plain text on stderr, not JSON**. So #158 in this design fails as a
confusing third error shape, not as an obvious one.

### 021's proposed escape does not exist; a different one does, and it works

021 §3.1 proposed the prompt be "written to a file and passed as a path, or sent with `agent prompt`
reading from a file". **`herdr agent prompt` in v0.8.2 has no file or stdin input** — its full option
set is `--wait`, `--until`, `--timeout`. The signature is `agent prompt <TARGET> <TEXT>`; the text
must be an argv element.

**The escape that works is task-file indirection**, and it is a natural twin of §3.2's answer file:

1. Motoko writes the model-authored prompt to `…/task-<id>.md` (FS, no argv involved).
2. `agent prompt` sends a **fixed, extension-authored, token-free** sentence:
   `Read the task described in <task-path> and carry it out. Write your final answer as Markdown to
   <answer-path>, then reply with only that file path.`
3. Both paths contain only `/ . - _` and alphanumerics, so the argv stays clean.

**Validated end to end.** A deliberately token-heavy task (backticks, `${d} && `, `<Config, Error>`)
was placed in a task file and delegated through the fixed sentence. The delegate read it, carried it
out correctly, and wrote a 1218-byte answer in 21.1 s. The argv carried no shell token.

**Consequence:** `ExtPorts.proc_exec` **is** reachable for this design, and #158 **is** avoidable —
but only if the prompt travels in a file. That is now a design requirement, not an optimisation, and
it also happens to be what §3.2 wanted for the return path. Both directions become files.

One caveat, inferred not measured: the guarantee depends on the answer/task paths being
token-free. Phase B's path builder should reject or escape any path containing one of the eight
tokens rather than assume `/tmp/...` is always clean.

---

## M5 — do delegates comply with "write your answer to `<path>`"?

**`claude`: 4 of 4, measured.** Every delegated task that named an answer path produced the file and
replied with only the path.

| run | shape | answer bytes |
|---|---|---|
| a1 | read README, 5 bullets | 1 755 |
| a2 | read 5 project markdown files, 400-word synthesis | 2 758 |
| a4 | **task-file indirection**, 3-part source question | 1 218 |
| c1–c4 | calibration batch, various | 181 / 948 / 1 715 / 7 141 |

Compliance included the awkward part: the reply on screen was the bare path and nothing else.
Content quality was high — the a4 answer correctly identified all eight shell tokens, the
`req.args`-dropping behaviour and the `cd ${d} && ` prefix, with line numbers.

The delegate wrote the file with a `Bash(… cat > …)` call that was **"Allowed by auto mode
classifier"** — this image's `claude` runs with `⏵⏵ auto mode on`, so no approval prompt appeared.
That is a property of the image's `~/.claude/settings.json`, not of the design; a delegate kind
without an equivalent would block. Recorded for F-4, not decided here.

**`codex`: measured on 2026-08-23 (P2-3), and the answer is more interesting than "yes".** Attended,
it complies (975-byte answer, path-only reply) — but unattended it **replied with the answer path
while never writing the file**. Compliance with the *instruction* is not the same as delivery of the
*artefact*.

**Verdict:** §3.2's answer-file channel is the **primary** path, as 021 hoped, not a fallback. The
`agent read --source recent-unwrapped` fallback should still exist, and M-extra-3 below is an
additional reason why.

---

## M6 — realistic wall-clock and answer size

**Measured**, true wall clock (submit → settled), `claude` delegate, `agent get` polled at 400 ms.
Trivial no-tool prompts: 2 361 ms and 3 448 ms. Realistic delegated tasks — read something, produce
an answer file:

| run | task | ms | answer bytes |
|---|---|---|---|
| C3 | count `.ail` files under `src/core` | 18 516 | 181 |
| medium | read `Makefile`, 150-word description | 20 618 | – |
| C1 | read `src/core/types.ail`, 120-word summary | 20 720 | 948 |
| a4 | task-file indirection, 3-part question | 21 130 | 1 218 |
| a2 | read 5 project markdown files, 400-word synthesis | 25 070 | 2 758 |
| C4 | read the 021 spec, 250-word summary of §7 | 25 516 | 1 715 |
| a1 | read README, 5 bullets | 28 334 | 1 755 |
| C2 | enumerate `Makefile` phony targets with descriptions | **91 241** | 7 141 |

**Answering the handoff's calibration ask directly:**

- **median wall clock: ≈ 23.1 s** (n = 8)
- **worst case: 91.2 s** — 3.6× the proposed bound, from an unremarkable-looking task
- **fraction exceeding a 25 s bound: 4 of 8 (50 %)**
- **answer file size: median 1 715 bytes, max 7 141 bytes** (n = 7). Small. Truncation is a
  non-problem at this scale; a 64 KB cap would never bind in this sample.
- **`agent_prompt_stalled` rate at a 25 s bound: 0 of 8** for ready delegates (M3).

**Therefore §4.1's "optimistic-synchronous under 25 s" default is wrong**, exactly as the handoff's
calibration ask anticipated. A coin-flip is not a fast path: half of all delegations would burn ~25 s
of a 30 s budget and *still* return a handle, having paid the full cost of waiting for nothing.

**Recommended replacement, poll-first:**

1. `Delegate` submits with **no `--wait`** (measured at 3–5 ms) and returns
   `{name, pane_id, answer_path, status: "working"}` immediately.
2. Optionally, one short confirmation wait — `--wait --timeout 3000` — purely to catch
   `agent_prompt_stalled`/`timeout` early. Even this is optional given M2's `explain` gate.
3. `DelegateCheck(name)` does `agent get` + read the answer file if present.

The economics strongly favour this: **`agent get` costs 4 ms, `agent list` 2 ms, `pane split` 16 ms,
`pane close` 1 ms.** Polling is essentially free; waiting is not. The model decides when to check
back, which is what 021 §4.1 said an agent loop is for — it simply had the default inverted.

Timings for completeness: `agent start` ~3.9 s (the only slow herdr call), `agent prompt` without
`--wait` 3–5 ms.

---

## Part 2 — `codex`, after authentication (2026-08-23)

The operator authenticated `codex` between Part 1 and Part 2. Configuration measured:
`~/.codex/auth.json` present, `auth_mode: chatgpt`, OAuth tokens stored, and its `OPENAI_API_KEY`
field explicitly `null`; `~/.codex/config.toml` now also marks `/workspaces/motoko_agent` as
`trust_level = "trusted"`. Env `OPENAI_API_KEY` remains empty. That is stored-subscription auth with
no API key — exactly the configuration 018 §5.1 needed and never had.

### P2-1 — `codex` silently ignores an env API key (018 §5.1, answered)

**Measured.** A pane split with
`--env OPENAI_API_KEY=sk-proj-INVALIDKEYFORTEST000000000000`, then `agent start --kind codex`:

- codex started normally — **no modal, no warning, no error**, status line `gpt-5.6-sol default`;
- prompted `What is 17 multiplied by 23?` it answered **`391`** correctly in ~4 s.

So `codex` **prefers its stored ChatGPT credential and ignores `OPENAI_API_KEY` entirely.** And with
`--env OPENAI_API_KEY=` (empty) it worked identically — empty reads as absent, as for `claude`.

**Combined with M1, this retires 018 F2's premise rather than confirming it:**

| CLI | inherited non-empty key, stored subscription auth present | silent billing inversion? |
|---|---|---|
| `claude` 2.1.240 | opens a modal — *"Do you want to use this API key?"*, default **No** | **no** — it blocks instead |
| `codex-cli` 0.149.0 | ignored entirely, uses stored ChatGPT auth | **no** — it ignores instead |

Neither CLI silently bills the wrong account. **Scope of the claim:** this holds *while stored
subscription auth is present*. With `auth.json` / the OAuth credential absent, an env key would
presumably be used — not measured, and not measurable without deauthenticating.

The practical value of `--env ANTHROPIC_API_KEY= --env OPENAI_API_KEY=` therefore is **not** billing
protection. It is that it stops `claude` from hanging on the startup modal (M1). Keep it; describe it
accurately.

### P2-2 — authenticated `codex` detects on a real rule

**Measured.** `agent start --kind codex` in **3 874 ms** (indistinguishable from `claude`'s ~3.9 s),
and `agent explain --json` now returns:

```json
{"agent":"codex","state":"idle","manifest_source":"bundled","manifest_version":"2026.08.09.1",
 "matched_rule":{"id":"osc_title_idle","priority":100,"region":"osc_title","state":"idle"},
 "fallback_reason":null}
```

Compare the unauthenticated run in M2: `matched_rule: null`,
`fallback_reason: "default_known_agent_idle_fallback"`.

**This is the important confirmation.** M2 proposed gating on
`matched_rule != null && fallback_reason == null` from a single broken example. Part 2 shows the
same predicate flips to *pass* for the same kind, in the same image, once the agent is genuinely
usable. The gate tracks **usability**, not agent identity. Phase B should adopt it.

(`codex`'s matched rule is `osc_title_idle` at priority 100 — a weaker signal than `claude`'s
`live_prompt_box` at 950, but a genuine match. The gate should test for *a* match, not a priority.)

### P2-3 — `codex` complies when attended; unattended it reports success without delivering

Two runs of the same answer-file shape, both with the billing guard applied.

**Run A — default approval policy (`on-request`).** Task: read `src/core/types.ail`, write a 120-word
summary to an answer path. Result: **complied — 975-byte answer file, reply was the bare path.**
Content was accurate.

But it took **five approvals**:

```
t+17ms     blocked -> approving (#1)
t+13322ms  blocked -> approving (#2)
t+19450ms  blocked -> approving (#3)
t+26588ms  blocked -> approving (#4)
t+31685ms  blocked -> approving (#5)
SETTLED    t+35779ms  status=done  approvals=5  bytes=975
```

reaching `blocked` first at **9.8 s** and settling ~45.6 s after submission (codex's own counter said
`Worked for 1m 01s`). Each approval was a single `herdr agent send-keys dlg-codex enter`.

**herdr reported every one of these as `blocked`** — the state is accurate, timely and pollable. For
the poll-first design of M6 this is a genuinely good result: `DelegateCheck` can surface *"your
delegate is waiting for approval"* as a first-class outcome rather than as a hang.

**Run B — `-a never` (`--ask-for-approval never`), started via `agent start … -- -a never`.**
Passthrough works: `argv: ["codex","-a","never"]`. Result: **0 blocks, 45 959 ms, settled `done`,
and the delegate replied with the answer path — but no file was ever written.**

The transcript says why:

```
# Unable to complete task
I could not read the task specification because every local command failed before execution
with the environment error:

    bwrap: No permissions to create a new namespace, likely because the kernel does not allow
    non-privileged user namespaces.
```

…and then `✘ Failed to apply patch`, because writing that very explanation also required executing
something.

**This is the single most important safety finding in this document.** A delegate can:

1. run to a clean `done`,
2. reply with exactly the answer path it was asked for,
3. and have written nothing at all.

**Requirement for Phase B:** `Delegate`/`DelegateCheck` must **stat the answer file independently**
and treat *path replied, file absent* (or file present but empty) as a distinct, named failure —
never as success. The reply text is a hint, not evidence. This applies to `claude` too; `codex`
merely made it observable.

### P2-4 — `codex` timings

| run | shape | wall clock | approvals | answer bytes |
|---|---|---|---|---|
| P2-1 | trivial, no tools ("17 × 23") | ~4 000 ms | 0 | – |
| Run A | read `types.ail`, 120-word summary, attended | 45 600 ms | 5 | 975 |
| Run B | task-file indirection, `-a never` | 45 959 ms | 0 | **0 (not written)** |
| Run C | task-file indirection, `-s danger-full-access -a never` | **27 629 ms** | 0 | 379 ✔ correct |

The honest comparison is Run C against `claude`'s **21 130 ms** on the *identical* task-file task
(M5, a4): unattended `codex` is about **1.3× slower**, not the 2.2× Run A suggests. Run A's penalty
was almost entirely approval round-trips, not model latency. Both kinds still exceed any bound that
fits inside Motoko's 30 s process wall, which is further evidence for M6's poll-first conclusion.

### P2-5 — `codex` cannot run unattended in `agent_confined`, and the reason is the container

**Measured root cause.** codex's Linux sandbox uses **bubblewrap**, which needs unprivileged user
namespaces. In this container they are unavailable:

```
$ unshare -U true
unshare: unshare failed: Operation not permitted
$ cat /proc/sys/user/max_user_namespaces
64282                       <- the kernel allows them
```

The kernel permits namespaces; the **container's stock seccomp profile blocks the `unshare` syscall
outright**. Full root-cause analysis, including a **correction to an earlier claim in this section
that Landlock was absent (it is not — ABI 8 is available)**, is in
`../019_agent_confined/FINDINGS-2026-08-23-sandbox-and-agent-permissions.md` F1. So:

- **approvals on** → each command is approved and runs *outside* the sandbox → works, N approvals;
- **`-a never`** → no approval path, so every command must go through the sandbox → `bwrap` fails →
  the delegate can do nothing (Run B).

There is no third setting that is both unattended and safe here. The remaining options are
`--dangerously-bypass-approvals-and-sandbox`, which the handoff's *Stop and report* list explicitly
forbids reaching for, or loosening the container's security profile — which is a **019 decision with
real security weight**, since confinement is the entire purpose of `agent_confined`. Note the irony
worth putting in front of the owner: codex's sandbox is largely *redundant* with the container, but
codex has no way to know that.

**Consequences for Phase B, none of which require closing an owner fork:**

- default to **`--kind claude`**, which is unattended-capable in this image;
- keep `kind` configurable, and do **not** hard-code an approval policy;
- because `blocked` is reported accurately and promptly (P2-3), `DelegateCheck` should expose it as a
  real state with the pane id, so a human can answer it. That is the *measured* form of 021 §5.3 and
  it does **not** decide F-4.

### P2-7 — unattended `codex` without a `--dangerously-*` flag (owner question, 2026-08-23)

The operator asked why `--dangerously-bypass-approvals-and-sandbox` is off the table given that
`agent_confined` is already the security boundary. Two separate answers, kept apart deliberately.

**On authority.** It was never established as forbidden. The handoff lists `--dangerously-*` under
*"Stop and report — do not decide these inline"*, which routes the decision to the owner rather than
prohibiting it. This session could not choose it; the owner can.

**On the merits — the container's actual posture, read from `docker-compose.yml`:**

| control | present? |
|---|---|
| `security_opt: no-new-privileges:true` | yes — and it is the *only* sandbox-shaped control |
| custom seccomp / `cap_drop` / `userns` config | **no** |
| sudo in the image | purged, and its absence asserted |
| host credential mounts (`~/.ssh`, `~/.claude`, `~/.config/gcloud`) | deliberately absent |
| `.devcontainer`, `.vscode`, `.git/hooks` | mounted `:ro` |
| the working tree | **bind-mounted read-write** — the file itself notes this "is ONE HOST DIRECTORY: isolating a compose service does not isolate `.git/config`, `.agent/` or `.env`" |
| outbound network | ordinary — "the model APIs, the npm registry and github.com all work" |

So the container protects **the host**. It does not protect the repository, `.env`, `GH_TOKEN`,
`LINEAR_API_KEY`, or the OAuth credentials under `/home/motoko` — which is the part codex's
workspace-write sandbox would otherwise have covered.

**That distinction does not survive contact with what already runs here, and the record should say
so plainly.** Both `claude` sessions in this workspace run with unrestricted shell access, no
sandbox, and `⏵⏵ auto mode on`. A bypassed `codex` delegate would sit at *parity* with them, not
above them. Refusing the delegate a permission the orchestrator already exercises is not a security
posture, it is an inconsistency. The owner's reasoning is sound.

**But the flag is the wrong instrument here, for a reason that is measured rather than cautious.**
In this container the "and-sandbox" half of `--dangerously-bypass-approvals-and-sandbox` is already
a **no-op** — `bwrap` cannot run either way (P2-5). What is actually wanted is "skip approvals", and
that has a narrower spelling:

```
herdr agent start <name> --kind codex --pane <id> -- -s danger-full-access -a never
```

**Measured (Run C):** `argv: ["codex","-s","danger-full-access","-a","never"]`, **0 approvals,
27 629 ms, 379-byte answer file written**, all three bullets of the task answered correctly
(including the full eight-token list and the `cd ${d} && ` prefix). Unattended `codex` works.

**Be honest about what this buys.** `-s danger-full-access -a never` is **equally permissive** —
full filesystem access, no approvals. It is not safer. What it is, is *legible*: two flags that name
exactly which control is being relaxed, in a config file that future readers will audit, instead of
one blanket flag whose name will stop every reviewer who meets it and which also disables a sandbox
that was never functional here. Same effect, accurate label.

### DECISION — owner, 2026-08-23: adopt `-s danger-full-access -a never`

The operator chose this over `--dangerously-bypass-approvals-and-sandbox` and over relaxing the
container's seccomp/capability configuration. **This section is the authoritative record.**

**What Phase B will do.** `--kind claude` stays the default: it is unattended-capable with *no*
relaxation at all and ~1.3× faster (P2-4). Per-kind extra argv becomes configurable, and `codex`'s
entry ships as `-s danger-full-access -a never`, commented with a pointer here — so the permissive
setting is opt-in, named, and attached to its evidence rather than buried in a default.

**What was granted, stated plainly so no later reader mistakes it for a sandboxed configuration.** A
`codex` delegate started this way has **unrestricted read/write access to everything the container can
reach** — the working tree (which is the operator's host directory), `.env`,
`~/.claude/.credentials.json`, `~/.codex/auth.json` — and **executes every command without approval**.
It is exactly as permissive as the `--dangerously-*` flag; the choice between them was legibility, not
safety (see above).

**The justification on record is parity, not containment.** Both `claude` sessions already running in
this workspace have identical reach and auto-approve their own tool calls. The decision declines to
hold a delegate to a standard the orchestrator does not meet. It does **not** rest on the container
being a sandbox — F1 of the 019 findings establishes that the container's protection is oriented at
the host, and that its stock seccomp profile is what broke codex's sandbox in the first place.

**One consequence this decision sharpens, flagged rather than decided.** 021 §5.1 already notes that
delegates outlive Motoko. Combined with this decision, the leaked object is no longer merely a running
agent — it is an **unattended, unsandboxed agent with full tree and credential access, still running
after its caller exited**. That does not change the decision; it raises the value of F-5 (orphan
ownership), which remains an owner fork. Phase B will take the narrowest behaviour that works —
`Delegate` closes its own pane on a terminal state, and `DelegateCheck` reports orphans it can prove
it owns — and will say so in the commit message rather than treating F-5 as closed. **No sweep will
kill a pane this extension did not create** (P2-6 shows why that matters concretely).

**This does not close F-4.** 018 §2.6's bypass concerns `agentcli`'s own subprocess and remains the
owner's, untouched here.

**Container-side findings extracted.** F1–F5 of
`../019_agent_confined/FINDINGS-2026-08-23-sandbox-and-agent-permissions.md` carry the parts of
P2-5/P2-7 that belong to 019 rather than to delegation — the user-namespace block, the silent-inert
`-a never` failure, the permission-state audit gap, and the ephemeral codex login.

### P2-6 — an ownership rule would have killed the operator's pane

While cleaning up, `herdr agent list` showed a `codex` agent at `w1:pG` that **this session did not
create** — the operator's own, from authenticating codex. Every delegate here was closed by explicit
pane id, so it survived.

This is 021 §5.1 / F-5 with a concrete instance instead of a hypothetical: a startup sweep that
reaped "codex panes that look like delegates" would have destroyed the operator's work. It reinforces
the handoff's *Stop and report* entry on orphan sweeps. Self-exclusion by `$HERDR_PANE_ID` (M-extra-4)
is **not sufficient** — the sweep also needs positive proof of ownership, not merely "not me".

---

## Findings not asked for, that Phase B needs

### M-extra-1 — the error surface has five shapes, not two

021 §5.4 says "two error vocabularies". Measured, there are **five**:

1. **herdr JSON error**, stderr, exit 1, one object per line:
   `{"error":{"code":"…","message":"…"},"id":"cli:<group>:<cmd>"}`.
   Codes observed first-hand: `timeout`, `agent_prompt_stalled`, `invalid_key`. Plus, from the 020
   briefing: `agent_not_found`, `agent_not_ready`, `agent_explain_unavailable`.
2. **CLI syntax error**, exit **2**, plain-text usage on stderr, no JSON
   (`herdr agent frobnicate` → the `herdr agent commands:` listing).
3. **Argument-validation error**, exit non-zero, **plain text, no JSON** —
   `env -u HERDR_PANE_ID herdr pane split --current` prints exactly
   `--current requires HERDR_PANE_ID`.
4. **Nested-herdr guard**, exit 1, **ANSI-coloured plain text, no JSON** — what #158's wrap produces
   inside a pane (M4).
5. **`ProcessError`** from `std/process.exec` — the seven constructors 018 F1 collapses.

And one non-error shape worth the same care: **`agent read` prints raw terminal text on stdout, not
JSON**, unlike every other successful call. `agent explain --json` prints a **bare** JSON object with
no `{"id","result"}` envelope. Any decoder that assumes "stdout is always `{"id":…,"result":…}`" is
wrong in two places.

**Recommendation:** decode on exit status first (0 / 1 / 2), then attempt JSON, then fall back to
"plain text diagnostic". Never predict `id` values; read them from `.result`.

### M-extra-2 — `--current` needs `HERDR_PANE_ID` after all

021 §4.4 argued the extension "may not need `HERDR_PANE_ID` at all" because `--current` resolves it
itself. True in the happy path — `HERDR_PANE_ID=w1:p8 herdr pane split --current` split `w1:p8`, not
the caller's pane, confirming the mechanism. But with it unset the call fails with the bare plain
text `--current requires HERDR_PANE_ID`. So the §4.4 gate should still require **all three** of
`HERDR_ENV=1`, `HERDR_BIN_PATH` and `HERDR_PANE_ID`, matching the TypeScript copy in
`src/tui/src/herdr-agent-state.ts` — which is what MOT-118 asks for anyway.

### M-extra-3 — the delegate's input box renders ghost text

Twice, `agent read` showed unsent text in the delegate's prompt box that nobody typed
(`show me the file contents`, then `now do the same for src/tui`). These are Claude Code's
**suggested-followup hints**, rendered in the input box; they are not buffered input, and the next
prompt was answered cleanly. `send-keys esc` and `ctrl+u` do not clear them.

Harmless for the answer-file channel — and a concrete argument against ever parsing the screen for
the result, since a naive scrape would return the suggestion as if it were content.

### M-extra-4 — self-inclusion is real, and pane ids are not decimal

`herdr agent list` run from this pane returns **this pane** (`w1:p7`, `claude`, name `herdr-021`)
alongside the delegates. 021 §4.6 predicted this for a Motoko row; it is equally true for a Claude
Code row. Exclude by `$HERDR_PANE_ID`, which is exact and cheap.

Also: **pane ids are not `w1:p<decimal>`.** Observed in this session: `w1:p8`, `w1:p9`, `w1:pA`,
`w1:pB`, `w1:pC`, `w1:pD`, `w1:pE`, `w1:pF`. Any parser or generator must treat a pane id as an
opaque string.

### M-extra-5 — approval prompts *are* answerable from a pane (§5.3's premise, measured)

The `claude` stuck on the API-key modal (M1) was released with a single
`herdr agent send-keys <pane> enter`, after which `agent explain` flipped from
`rule: none / fallback_reason: default_known_agent_idle_fallback` to
`rule: live_prompt_box`. So 021 §5.3 is factually correct: a pane makes approval prompts answerable.

**This does not decide F-4** — the handoff reserves that for the owner, and nothing here was built
on it. Recorded only as the measured premise. Note also that `send-keys` has its own key vocabulary:
`esc` and `ctrl+u` are accepted, `ctrl-u` and `C-u` return
`{"error":{"code":"invalid_key","message":"unsupported key ctrl-u"}}`.

### M-extra-6 — `pane close` is a complete orphan remedy

Closing a delegate's pane removed it from `agent list` immediately (1 ms). Both delegates created
for these measurements were reaped this way, and `agent list` returned to its pre-measurement
contents. Relevant to §5.1/F-5, which remains the owner's to design — but the mechanism is cheap and
verified.

---

## What could not be measured, and why

1. ~~Anything requiring a working `codex`.~~ **Resolved 2026-08-23** — the operator authenticated
   codex and Part 2 takes every measurement that was blocked on it.
2. **Whether an env key wins when stored subscription auth is *absent*.** Both CLIs were measured
   with stored auth present (M1, P2-1), and in that state neither prefers the env key. The
   credential-free case is not measurable without deauthenticating one of them, which would undo the
   operator's work. Inferred, not measured: an env key would then be used.
3. **Whether `codex` could run unattended with the container's security profile loosened.** P2-5
   identifies the blocker (`bwrap` / unprivileged user namespaces) but the fix is a `019` image and
   security decision, not something to test by mutating the running container.
4. **Kinds other than `claude` and `codex`.** herdr lists 22; two were exercised.
5. **Multi-delegate concurrency (F-6).** Not attempted; delegates ran at different times, never
   simultaneously against the same tree.

## Housekeeping

`git status` after Phase A shows only `.devcontainer/agent_confined/{Dockerfile,herdr.toml}` and
`ailang.lock` — the read-only-mount artefacts described in the 020 briefing §2. **No file in the
repository was modified by these measurements**; all scratch (task files, answer files, timing
scripts) was written under the session scratchpad outside the tree.

All delegate panes created here were closed, by explicit pane id. `herdr agent list` is back to its
pre-measurement contents plus the operator's own `codex` pane at `w1:pG`, which this session
deliberately left alone (P2-6).
