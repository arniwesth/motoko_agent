# NOTE: Collapse the env-scrub bug class — one manifest, derived allowlist, DST completeness check

Date: 2026-07-05
Status: Proposed follow-up WI (spun out of ADR-002; not blocking it)
Relates to:
- `ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` §5 — this NOTE is the host-side
  residue ADR-002 declared out of scope.
- PR **#76** commit `c5b0924` ("derive the subprocess env allowlist from `config.ts`") — the
  partial precedent; **not present on this branch**.

---

## The recommendation this NOTE captures

> Collapse the broader scrub class by unifying to one manifest (ideally AILANG-owned), turning the
> host-side half from "a whole untestable mechanism" into "a trivial conformance check."

This NOTE is the concrete WI for exactly that sentence. It does **not** try to move the scrub
*mechanism* into AILANG (impossible — see "The irreducible boundary"); it moves the *authority*
to a single source of truth and adds an AILANG-side check, so the untestable host residue shrinks
to one mechanical drift-guard.

## The bug class

`SYSTEM_MD` scrubbed (#76) was the **5th** instance of one class: the AILANG runtime is spawned
with an explicit env allowlist, and any var not on the list is silently dropped, so an env-gated
feature fails invisibly. PR #76's body lists the prior four (`MOTOKO_REPO`,
`MOTOKO_PERSIST_RETRIES`, `AILANG_OLLAMA_MAX_TOKENS` — added twice —, `AILANG_STDLIB_PATH`).

Root cause: **two disconnected lists.**
- `CORE_MAP` (`src/tui/src/config.ts:22`) + `EXTENSION_MAPS` (`:57`) — the manifest mapping
  logical config keys → env vars (e.g. `"agent.system_prompt": { env: "SYSTEM_MD" }`), used to
  load config.
- `childEnv` (`src/tui/src/runtime-process.ts:342-411`) — the **hand-maintained** spawn allowlist,
  bound at `spawn(..., { env: childEnv })` (`:531`).

A var in `CORE_MAP` but forgotten in `childEnv` loads into config yet never reaches the child. The
two lists drift; every drift is a silent feature outage.

## The irreducible boundary (why the mechanism stays host-side)

A process's initial environment is fixed by its **parent** at `execve` time. AILANG core is the
**child** of the TUI spawn (`runtime-process.ts:512-531`); it cannot decide the env it was born
with. Pushing logic up into a thinner launcher only moves the boundary — there is always a
top-level process whose env is given by a shell / systemd / the eval harness. So "AILANG owns the
allowlist" is a chicken-and-egg impossibility. What we can own in AILANG is the **contract** the
host must honor, plus a check that core's own declared needs are complete.

## Proposal

### WI-1 (mechanical, high value): derive `childEnv` from the manifest

Replace the hand-maintained `childEnv` literal with a build that iterates
`CORE_MAP ∪ EXTENSION_MAPS` and forwards each entry's `.env` from `process.env` (preserving the
existing default/serialize semantics). Special cases that are *not* config-mapped (`PATH`, `HOME`,
API keys, `AILANG_FS_SANDBOX`, OTLP block) stay explicit but segregated from the config-derived
set. Effect: "forgot to forward X" becomes **impossible by construction** — adding a `CORE_MAP`
entry forwards it automatically. This is PR #76 `c5b0924`, re-landed on this branch.

### WI-2 (stronger, optional): make the manifest AILANG-owned + DST-checkable

Today the manifest lives in TS (`config.ts`) while the *consumer* is AILANG (`cfg.agent.*` reads
in `rpc.ail`/`session.ail`). Co-locate the source of truth with the reader:
- Core exports a pure `env_manifest : [ConfigKey]` (or a generated artifact) enumerating every
  config key it consumes and the env var each maps to.
- The launcher **generates** `childEnv` from that manifest (a generated JSON the TS side reads),
  so TS holds no independent list.
- **DST manifest-completeness scenario** (L0, `--caps` none): assert every `cfg.agent.*` /
  `cfg.tools.*` field core actually reads has a matching `env_manifest` entry, and that each entry
  is wired to a `ports.env_get` read. "Core needs env X but forgot to declare it" then fails as a
  **red AILANG scenario**, not a silent production outage.

### The residual host test

Whichever of WI-1/WI-2 lands, the only remaining TS test is a one-line drift-guard:
`keys(childEnv) ⊇ envVars(manifest)`. That is the whole untestable host surface — down from an
N-item hand-list where any omission silently breaks a feature.

## What this does and does not buy

- **Does:** collapses the scrub *class* to impossible-by-construction; gives AILANG DST a
  completeness check over core's own env contract; shrinks the host residue to a mechanical
  conformance check co-generated from one source.
- **Does not:** let core observe whether the *real* parent honored the contract at *real* spawn —
  that stays a host test by OS necessity. The win is **thin + derived + single-source**, not zero.

## Relationship to ADR-002

Orthogonal and complementary. ADR-002 catches the *symptom* (an empty served prompt) at the
`seal` gate regardless of cause — the robust in-core backstop. This NOTE attacks one *cause* class
(env drift) upstream so features don't silently mis-wire in the first place. Neither depends on the
other; ADR-002 ships without this, and this improves every env-gated feature, not just the system
prompt.

## Suggested sizing

WI-1 is a few hours (mechanical TS refactor + the one-line drift test; the `c5b0924` diff is a
reference). WI-2 adds the AILANG `env_manifest` export, the launcher codegen, and one L0 scenario —
a small day, most of it the codegen wiring. WI-1 alone already retires the bug class; WI-2 is what
makes the contract DST-visible.
