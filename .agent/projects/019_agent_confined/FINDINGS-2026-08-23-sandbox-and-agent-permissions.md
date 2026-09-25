# FINDINGS: sandboxing and agent-permission state in `agent_confined`

Date: 2026-08-23
Measured in: the running `agent_confined` container (`ab3ed0fab4f6`), herdr 0.8.2,
`claude` 2.1.240, `codex-cli` 0.149.0
Found by: the 021 session, while measuring delegation (`021/MEASUREMENTS-2026-08-22.md`, Part 2)
Status: **findings only — no decision taken, nothing changed.** Every remedy below is 019's owner's.

**Why this file exists rather than an edit to the README.** `.devcontainer/**` is mounted `:ro` in
this container, so `README.md`'s *Known gaps* and the *what is absent* table — the natural homes for
F1–F4 — cannot be edited from here. Fold these in from a host shell.

**On framing, before anything else: 019 already got this right.** These findings do **not** show the
README overstating the boundary. Its *"What is deliberately **not** absent"* section already says
"an operator who reads only that table will overestimate the boundary", already documents that the
tree is mounted whole and that in-tree credentials stay reachable. What follows adds **measured
facts that are not yet written down anywhere**, not a correction of framing.

The one thing worth stating plainly for people who describe this container in conversation rather
than from the README: the only *sandbox-shaped* control in `docker-compose.yml` is
`security_opt: no-new-privileges:true`. There is no custom seccomp profile, no `cap_drop`, no
`userns` configuration. The real controls are architectural — sudo purged, no host credential
mounts, no docker socket, no ssh, `:ro` binds, a curated env, a machine-user token. That is a
meaningful boundary **around the host**, and it is not the same thing as sandboxing what runs inside.

---

## F1 — the stock seccomp profile blocks `unshare` outright; Landlock, however, works

**Corrects an earlier draft of this file**, which claimed "Landlock is absent as well". That was
wrong, and wrong in an instructive way: it was inferred from `/sys/kernel/security/landlock` not
existing — but **securityfs is not mounted in this container at all**, so that directory proves
nothing about kernel support. Asked directly, the kernel answers:

```
$ python3 -c 'landlock_create_ruleset(NULL, 0, LANDLOCK_CREATE_RULESET_VERSION)'   # syscall 444
  SUPPORTED — Landlock ABI version 8
```

**Landlock is fully available here.** Anything below that turns on "no sandbox primitive exists" is
false; the real constraint is narrower and more specific.

### What is actually blocked, and by what

```
$ uname -m -r                  aarch64  7.0.14-orbstack-00380-ga7e0a2dc9535
$ cat /proc/sys/user/max_user_namespaces      64282     <- kernel permits user namespaces
$ grep Seccomp /proc/self/status              Seccomp: 2, Seccomp_filters: 1
$ grep CapEff  /proc/self/status              CapEff: 0000000000000000
  bounding set: CHOWN DAC_OVERRIDE FOWNER FSETID KILL SETGID SETUID SETPCAP
                NET_BIND_SERVICE NET_RAW SYS_CHROOT MKNOD AUDIT_WRITE SETFCAP
  CAP_SYS_ADMIN: NO
```

`unshare()` probed per flag, each in a forked child:

| flags | result |
|---|---|
| `CLONE_NEWUSER` | EPERM |
| `CLONE_NEWNS` | EPERM |
| `CLONE_NEWPID` | EPERM |
| `CLONE_NEWNET` | EPERM |
| **`0` (no flags at all)** | **EPERM** |

**That last row is the diagnosis.** `unshare(0)` is a no-op requiring no privilege; the kernel
returns 0 for it unconditionally. Getting EPERM means the call never reaches the kernel — **a seccomp
filter is rejecting the `unshare` syscall wholesale**, not filtering on `CLONE_NEWUSER`.

Which filter: the container carries one seccomp filter and no `CAP_SYS_ADMIN`. Docker's **default**
seccomp profile permits `unshare` only for containers holding `CAP_SYS_ADMIN`. So this is **stock
Docker behaviour, not something 019 configured** — `docker-compose.yml` sets no `seccomp=`, no
`cap_add`, no `userns_mode`; its only `security_opt` is `no-new-privileges:true`, which is unrelated.

**Inference, not measured:** `.devcontainer/docker-compose.yml` (the operator's profile) likewise sets
no `security_opt`, `cap_add` or seccomp override, so the operator's container almost certainly behaves
identically. Untested from here — it would need a shell in that container.

### Why this defeats `codex` specifically, and why "use the other backend" does not rescue it

The codex binary ships **both** sandbox backends — `strings` finds `Landlock`, `LandlockRuleset`,
`LandlockCommand…` alongside `bwrap`, `Bubblewrap`, `CODEX_BWRAP_SHA256`. Since Landlock works here
(ABI 8), the obvious question is whether codex can be told to use it. There is a key for exactly
that, `use_legacy_landlock`. **Measured — it does not help:**

```
herdr agent start … --kind codex -- -c use_legacy_landlock=true -s workspace-write -a never
```

Every command still failed before execution, now with a different message:

```
permission profiles requiring direct runtime enforcement are incompatible with --use-legacy-landlock
```

So in 0.149.0 the Landlock path is a **legacy** route that its current permission-profile enforcement
has outgrown; the supported enforcement path needs bubblewrap, and bubblewrap needs the `unshare` the
seccomp profile denies. The blocker is therefore precisely:

> **codex 0.149.0's current enforcement path requires user namespaces; the stock Docker seccomp
> profile denies them. It is not that this container cannot sandbox.**

(Not tested: `use_legacy_landlock` with a profile that needs no runtime enforcement, e.g.
`-s read-only`. It could not have produced an answer file, so it was not pursued — but it would settle
whether codex's Landlock path functions here *at all*, which matters if a later version revives it.)

Incidentally this run produced a **third** instance of the F2 failure shape: the delegate settled
`done`, replied with the answer path, and wrote nothing — the file explaining the blocker also failed
to apply. It also tried to `Search the web for file:///tmp/…`, a degradation worth knowing about.

### Remedies and what each costs

| option | effect | cost |
|---|---|---|
| leave as is | codex is attended-only (F2) | five approvals per task |
| `-s danger-full-access -a never` (F3) | unattended codex, **no sandbox** | full filesystem access, no approvals |
| `cap_add: [SYS_ADMIN]` | bwrap works, codex sandboxes properly | **grants the container the single most powerful capability** — strictly worse than F3 |
| `security_opt: [seccomp=<profile allowing unshare>]` | bwrap works, narrowest real fix | a custom profile to author, review and maintain |
| use `--kind claude` | unattended with no relaxation at all | none — this is the recommendation |

**Note the ordering, because intuition inverts it:** `cap_add: SYS_ADMIN` *sounds* like the principled
fix ("let the sandbox work") and is in fact the most dangerous option on the list — it is close to
container root and applies to every process in the container, whereas F3's blast radius is one codex
process that already had the operator's tree. If codex must run unattended here, F3 is the safer of
the two.

## F2 — `codex`'s sandbox therefore cannot run, and its no-approval mode is silently inert

`codex` uses **bubblewrap** for its Linux sandbox. With F1 in force:

- **default (`-a on-request`)** — codex asks before every model-generated command; approved commands
  then run **outside** any sandbox. Workable, but a trivial task took **five** approvals and ~45.6 s.
  Measured messages name the cause: *"May I read the requested source file outside the unavailable
  sandbox…"*.
- **`-a never`** — no approval path exists, so every command is routed through the sandbox, and
  every command fails:

  ```
  bwrap: No permissions to create a new namespace, likely because the kernel does not allow
  non-privileged user namespaces.
  ```

  **The dangerous part is the shape of the failure, not the failure.** In the measured run the agent
  finished at a clean `done`, replied with exactly the output path it had been asked for, and had
  written nothing — the file it tried to write to explain the problem also failed to apply. An
  orchestrator trusting the reply would record a success.

## F3 — `-s danger-full-access -a never` restores unattended `codex` (measured) — **ADOPTED 2026-08-23**

```
herdr agent start <name> --kind codex --pane <id> -- -s danger-full-access -a never
```

**Measured: 0 approvals, 27 629 ms, answer file written, content correct.**

Recorded here because the obvious alternative,
`--dangerously-bypass-approvals-and-sandbox`, is **strictly worse as documentation and identical in
effect**: in this container its "and-sandbox" half is already a no-op (F1), so both spellings grant
full filesystem access with no approvals. The two-flag form names which control is being relaxed.

**It is not safer. It is legible.** Anyone adopting it should say so in the same breath.

**Owner decision, 2026-08-23: adopted.** The operator chose F3 over
`--dangerously-bypass-approvals-and-sandbox` and over relaxing the container. What was granted, stated
plainly so it is not later mistaken for a sandboxed configuration: **a `codex` delegate started this
way has unrestricted read/write access to everything the container can reach — the working tree,
`.env`, `~/.claude/.credentials.json`, `~/.codex/auth.json` — and executes without approval.** The
justification on record is parity, not containment: the `claude` sessions already running here have
exactly the same reach (P2-7 in the 021 measurements). The authoritative statement of the decision and
its scope is `../021_herdr_delegation/MEASUREMENTS-2026-08-22.md` §P2-7.

## F4 — agent permission state lives outside the tree's audit surface

019 leans on a property stated in `HISTORY.md`: *"what is the agent running is answerable from
`git log` rather than from whoever last built."* Pinned versions honour that. **Agent permission
configuration does not.**

Measured, all created at runtime and none of them in the tree or the Dockerfile:

| path | contains | created |
|---|---|---|
| `/home/motoko/.claude/settings.json` | a herdr `SessionStart` hook, **`"skipDangerousModePermissionPrompt": true`**, theme, notification prefs | 2026-08-22 17:01, at `agent.sh bootstrap` |
| `/home/motoko/.codex/config.toml` | `[features] hooks`, **`[projects."/workspaces/motoko_agent"] trust_level = "trusted"`**, a hook `trusted_hash` | image + runtime |
| `/home/motoko/.codex/auth.json` | ChatGPT OAuth tokens (`auth_mode: chatgpt`) | runtime login |

**Provenance of `skipDangerousModePermissionPrompt` is not established.** `agent.sh bootstrap` runs
`herdr integration install claude`, which does create this file — but the herdr binary contains no
occurrence of that key (`strings /usr/local/bin/herdr | grep -i skipDangerous` → no match), so herdr
did **not** write it. It was written by Claude Code itself or by a human. **Do not record it as a
herdr behaviour without checking further.**

Separately and independent of provenance: the baked-in `claude` was observed running with
`⏵⏵ auto mode on`, auto-approving its own tool calls (*"Allowed by auto mode classifier"*). No
settings file found here sets that, so it is most likely this Claude Code version's default rather
than an image choice — **stated as observation, not as a configured property.**

**The finding is the audit gap, not any single key.** Whether the agent asks before acting is decided
by files that `agent.sh check` / R9 do not inspect, `git log` cannot answer for, and a rebuild
silently resets. R9 already asserts things of comparable weight (sudo refused, no docker socket, which
account answers). A leg asserting the *permission posture* of the baked-in CLIs would close it.

## F5 — the codex login taken on 2026-08-23 will not survive a rebuild (operational, act if you care)

Not a new finding — `docker-compose.yml` and the README's absence table both say subscription logins
do not persist, because nothing mounts `/home/motoko`. Flagged because it is now **live**: the
operator authenticated `codex` on 2026-08-23, and `agent.sh stop` / `agent.sh build` will discard it
along with `~/.codex/auth.json`.

The opt-in is already written out in `docker-compose.yml` — four volume lines plus a top-level
`volumes:` block — with the note that "nobody has taken that decision". Taking it trades the security
property (*a rebuilt container has no credential until you give it one*) for not re-authenticating
each rebuild. **Still nobody's decision to take but the owner's**; it is simply more expensive to
defer now that a login exists to lose.

---

## Suggested dispositions (none taken)

| # | remedy | owner |
|---|---|---|
| F1 | document in the *what is absent* table: the stock seccomp profile denies `unshare`, so `bwrap`-based sandboxes cannot start (Landlock **is** available — do not repeat the retracted claim) | 019 |
| F2 | note that `codex -a never` fails **silently and successfully-looking** in this container | 019 / 021 |
| F3 | ~~if unattended `codex` is wanted, prefer the two-flag form~~ — **decided 2026-08-23: adopted**; Phase B ships it as `codex`'s per-kind argv, opt-in and commented | done |
| F4 | add an R9 leg asserting the baked-in CLIs' permission posture; consider baking `~/.claude/settings.json` so it is reviewable in the tree | 019 |
| F5 | take or explicitly re-defer the `agent_home_{claude,codex}` volume opt-in | owner |

Cross-reference: `.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-08-22.md` §P2-3, P2-5, P2-7
carry the full transcripts and timings behind F2, F3 and the delegation-side consequences.
