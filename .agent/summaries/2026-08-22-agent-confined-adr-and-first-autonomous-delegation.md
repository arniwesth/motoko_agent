# 2026-08-22 `agent_confined`: the decision record, and the first autonomous delegation

## Context

Worked **from inside `agent_confined` itself**, in a herdr pane, as `motoko-agent` — which is the
point of the profile and also the source of half the findings below.

Entry point was `.agent/projects/019_agent_confined/HANDOFF-formalize-agent-confined.md`: the
confined-container profile was complete and in daily use, but its project directory held only the
handoff. Every "why" lived in comments at the point of decision and in a chronological `HISTORY.md`,
neither of which states a decision *as a decision*.

The session ran well past that brief. It ended with five PRs, seven Linear issues, one restructure of
work that was already pushed, and a delegated agent that shipped a feature and got its own identity
wrong.

## What shipped

Five stacked PRs on `arniwesth/motoko_agent`, each single-topic:

```text
#169  mot-101   -> mot-159   the implementation (operator's), minus agent_confined
#168  mot-102   -> mot-101   the agent_confined profile + ADR-001
#170  mot-111   -> mot-102   Linear attachment in tools/pr        <- written by a delegate
#171  mot-113   -> mot-111   the delegation findings, 021 §8
#172  mot-114   -> mot-113   herdr's skill for claude and codex
```

Linear **MOT-102** (parent) with sub-issues **MOT-103**–**MOT-110**, plus **MOT-111**, **MOT-112**,
**MOT-113**, **MOT-114**.

## The ADR, and two premises it falsified

`ADR-001-confined-agent-container.md` states D1–D11 with alternatives and C1–C10 with consequences:
no `devcontainer.json` and never attached; no sudo, ssh, docker socket or host credential mounts;
herdr as the session layer; the deliberate `GH_TOKEN` mapping that *inverts* 016's naming rule for
this profile only; a curated environment rather than `env_file`; pinned versions with `upgrade` as a
separate verb; the three `:ro` binds and their `EROFS` consequence; what is deliberately **not**
absent; all work happening here; and the carve-out that the profile cannot be maintained from inside
itself.

Both acceptance runs were completed and pasted into grounding blocks — the container legs from
inside, the host legs by the operator, because `agent.sh` refuses to run inside a container by
design. Measurement then contradicted the handoff twice:

**R9 leg 6 cannot pass on OrbStack.** `host.docker.internal` resolves to `0.250.250.254` even though
`extra_hosts` is absent and `/etc/hosts` carries no entry — OrbStack supplies the name over **DNS**,
as it does `gateway.docker.internal`, `host.orb.internal` and `docker.for.mac.host.internal`. The leg
tests the name's absence as a proxy for "`extra_hosts` was added back", and that proxy is invalid
here. It was already narrowed twice for confusing a name with a route; this is the same confusion on
the detection side. **MOT-107.**

**`OBSIDIAN_MCP_TOKEN` was not removed**, though the handoff sanctioned it as the single allowed
behaviour change. Its stated premise — that this container cannot address the obsidian server — is
false: the name resolves and the host is routable (connection *refused*, not a timeout). Removing a
granted token on a rationale measurement disproves is a worse record than leaving it. **MOT-106.**

The R7 audit was recorded and verified. Its most useful result was accidental: the host baseline read
`branch=509` where the container run read `506`, the difference being this session's own branch
entries, with zero shape violations either way. That is the clearest demonstration available that
f-1(2) is a **typed** expectation and not a snapshot — ordinary work moved the count and the audit
did not blink.

## Two operator decisions

`code-graph/` **deleted** (untracked, gitignored, 105 MB, 1004 files). The hazard was a name
collision with the *tracked* `tools/code-graph/`, so both were verified distinct before removal, and
its one nested repo checked for unpushed commits. Knock-on: R7 now walks five configuration files
rather than six, so any baseline predating the deletion false-fails.

**History rewrite declined.** The removed terms stay in ~10 pushed commits. `.agent/github/` keys off
commit SHAs and, after D10a, is the only place the human/mechanism distinction survives — breaking it
to scrub a name is a poor trade. **MOT-110**, closed as decided rather than left open.

## Restructuring already-pushed work, without a rewrite

`#169` was a grab-bag: the container profile, the herdr state reporter, five project directories, a
Makefile and `.mcp.json`. Reviewing the boundary in one PR and the reasoning for it in another was
the wrong split.

Fixed with **no history rewrite**: a new commit on `mot-101` removing the `agent_confined` paths, and
a `-s ours` merge on `mot-102` that incorporates the removal as history while keeping this side's
tree. `-s ours` was not a stylistic choice — a normal merge would have tried to *delete*
`.devcontainer/agent_confined/**` from a read-only mount and failed part-way with `EROFS`. The
carve-out the ADR documents, met while landing the ADR.

## The first autonomous delegation

A `claude` delegate was started in a herdr pane, handed a 43-line brief, and left to implement
MOT-111 end to end — write `tools/pr/linear.ts`, test it, commit, push, open PR #170. **It
succeeded**, and proved itself by attaching its own PR to its own Linear issue through the code path
it had just written. It kept the API key off argv, made every failure non-fatal, made the operation
idempotent, and stayed in scope. Recorded as `021_herdr_delegation/RESEARCH-…` §8.

Four findings, all from the mechanism rather than the payload:

**F-A — `herdr agent wait` misses the transition on a long wait.** A 45-minute wait launched while
the agent was `working` never fired when it went idle; it exited only when killed, which is why the
completion notification never arrived. Three controls behave correctly against the same agent, so it
is specifically the long-lived wait that loses the edge. **Poll `agent list` instead.** This also
makes §7 item 3 suspect rather than merely open — likely the same machinery. Worth reporting upstream
(herdr 0.8.2).

**F-B — `agent start` fails on the CLI's first-run prompts, not on detection.** `agent_not_ready`
turned out to be a fresh `claude` blocking on *"Try the new fullscreen renderer?"*. This **answers**
§7 item 2, which feared a detection failure "fatal to the whole design": detection is in fact more
forgiving than assumed — herdr registered the pane itself despite the start erroring.

**F-C — a brief is a pointer, not a payload.** Newlines in a TUI input read as submissions, so the
brief was staged on disk and its path passed. That also leaves an artifact the run can be audited
against.

**F-D — the delegate took its git identity from history.** It ran
`git -c user.name="motoko-agent" -c user.email="<operator>" commit`, having just read `git show`
output and copied the author it saw. Its commits read as the bot in `git log` while **GitHub
attributed them to the operator** — inverting the exact property D5 and D10a exist to guarantee.

**R9 leg 4 would have passed throughout**, for two separate reasons: it asserts *configuration*
rather than what the commits carry (so `git -c`, `--author` and env overrides all bypass it), and it
never checks the email at all — the half that decides GitHub attribution. **MOT-112.** The commits
were replayed with the correct identity, author dates preserved, tree byte-identical; the check gap
remains open.

Worth stating plainly: the delegate was not being careless. Matching surrounding convention is
normally the right instinct, and it had no way to know this repository's history is the one thing it
must not imitate. **A harness must make identity non-inferable, not merely configured.**

## Linear, and the herdr skill

The PR↔issue link was being made by hand and therefore forgotten — which is how it was noticed
missing. Native linking did not fire; diagnosis needed `admin:repo_hook`, which the bot deliberately
lacks. So it went into the pipeline (MOT-111), where it is deterministic. The operator then granted
the repo to the Linear GitHub App mid-session, and the native path started working between #170 and
#171 — the two coexist, distinguishable because the pipeline prefixes `#<n> `. One wrinkle: stacked
PRs cross-link, because Linear matches the **base** branch too.

herdr's own skill was added at `.claude/skills/herdr/SKILL.md`, taken from `herdr --skill` and
verified byte-identical to the v0.8.2 tag. Sourcing it from the binary matters: `versions.env` pins
the version, so the binary is the authority, and a copy from a tag URL can drift after
`agent.sh upgrade` with nothing to report it.

Codex is where the durability question bites. `claude` reads the *project* copy on the bind mount and
is safe by being in git; codex reads **only `$CODEX_HOME/skills`**, which is in the image and is
discarded by every rebuild. Installed by hand and verified against the running agent; the durable fix
is a Dockerfile symlink to the same reviewed file — tested, not assumed, since codex resolves a skill
through a link. **MOT-114**, host-side.

## Operational note

Early in the session an `env | grep` redaction pattern failed to match `GH_TOKEN=` — the word `TOKEN`
sits left of the `=` — and printed the live bot PAT into the transcript. **`MOTOKO_BOT_GH_TOKEN`
should be rotated.** Nothing else needs changing: the container resolves it at run time and no secret
is baked into the image.

## Still open

- **MOT-106** `OBSIDIAN_MCP_TOKEN` — premise falsified; the scope question is the owner's.
- **MOT-107** R9 leg 6 — replace the platform-DNS proxy with a compose-file grep.
- **MOT-108** the operator's devcontainer stays unhardened, now a standing accepted risk.
- **MOT-112** leg 4 asserts configuration, not outcome, and never checks the email.
- **MOT-114** the codex symlink stanza.
- The R7 baseline is invalid again — the operator's `8d7954b` and the new skill both changed the
  f-4 frozen set. ADR-001 C2 firing as designed.
- Every one of those fixes is **host-side**, because `.devcontainer/**` is `:ro` here. That is D11,
  and this session was a sustained demonstration of it.

## What this session actually established

The profile works: legs 2–5 pass, the bot identity holds by construction, a delegate can be started,
briefed, and left to ship a PR. What it does *not* yet have is a harness that makes the right thing
automatic — `agent wait` cannot be trusted, first-run prompts block an autonomous start, and identity
is inferable by an agent that reads history. Each of those was found by doing it rather than by
reasoning about it, which is the argument for having done it at all.
