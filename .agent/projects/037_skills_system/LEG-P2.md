# LEG-P2 — Amendment 5 and the host rejection (PLAN-001 §4, dagr task `P2`)

You are a delegate of the 037 orchestrator, invoked through the `Delegate` tool. You own
exactly this task. You do not implement any other part, you do not edit the plan, you do
not write any dagr run file, and you do not touch other panes, tabs or worktrees.

## What this is

`P2` in `PLAN-001-implement-adr-001.md` §4, released at G1 by the operator (revise-first
ruling 2026-10-04: D8 and the ruling-record text are revised separately; P2's surface is
untouched by those revisions). The host refusal for a broken skill root: the reader,
`RegistrationRefused`, and its three arms in `registry_normalize.ail`, plus Amendment 5
to 031 ADR-001. No ABI version change.

Operator rulings already recorded: Amendment 5 lands **before** the 033 release tag
(Q5); the amendment **text** still needs the operator's approval when you present it —
write the text, attach the artifact, and STOP that leg (do not land the 031 edit without
approval; say exactly what the edit says).

## Where you work

Worktree `/workspaces/motoko_agent-skills`, branch `feat/skills-extension` (verify with
`git rev-parse HEAD` and `git branch --show-current` before you start; record the HEAD).
Your `cwd` is that worktree root. Do not touch the shared checkout at
`/workspaces/motoko_agent`, the worktrees `/workspaces/motoko_agent-p1proto`,
`/workspaces/motoko_agent-fix3`, `/workspaces/motoko_agent-cgraph-iface`, or any other
session's panes, tabs or paths. Push nothing.

## Ground truth to read first, in this order

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §4 (this part, all four steps).
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — **D2** (key name
   `registration_refusal`, semantics, order before the multiplicity walk, the fail-safe,
   the same-string row) and **A4** (the four pure-test cases + ordinary registration).
3. `src/core/ext/registry_normalize.ail:154,164,174` (`rejection_rule`,
   `rejection_extension`, `rejection_message`), `:330` (`normalize_registration`), and
   `:543` (`ext_config_digest` — read it so your reader sits beside it correctly, do not
   change it).
4. `scripts/dst/registry_multiplicity_dst.ail` — the registration-boundary script (the
   artifact fixture goes here; it runs under `make dst`, not CI).
5. `packages/motoko-ext-abi/types.ail` — the comment beside `ExtRegistration` (amendment
   states the key there; **no code and no version change** in the ABI package).
6. `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`
   — lines 6–7 and acceptance rule (ii) (~line 1094): the amendment format and where
   Amendment 5 goes.

## What you build, in this order

1. **The artifact first.** A fixture in the registration-boundary script: a registration
   whose `config` carries `registration_refusal`, accepted by the host as it stands.
   Confirm it passes now — it is the test that turns red when the check lands, and what
   Amendment 5 cites.
2. The reader, `RegistrationRefused`, and the arm in each of `rejection_rule`,
   `rejection_extension`, `rejection_message`, checked **before** the multiplicity walk.
   `new_contract_policy` covers `src/core` only — your reader lives there, so it applies.
3. Inline tests for ADR A4: non-empty string refuses; non-string value refuses; absent
   key, empty string, and an ordinary registration are accepted.
4. Amendment 5 text for 031 ADR-001 with the artifact attached, plus the ABI comment
   beside `ExtRegistration`. Then STOP that leg and present the exact text — the 031 edit
   lands only on the operator's approval of the words.
5. The same-string row in `registry_multiplicity_dst.ail`: extension and host use the
   same key.

Green when: `ailang test src/core/ext/registry_normalize.ail`,
`make registry_multiplicity`, `make check_core`, `new_contract_policy` all pass. Against
the P0 baseline (`evidence/baseline/BASELINE.tsv`): no newly-red gate.

## Rules that bind you

- Touch only: `src/core/ext/registry_normalize.ail`,
  `scripts/dst/registry_multiplicity_dst.ail`, the `ExtRegistration` comment in
  `packages/motoko-ext-abi/types.ail`, the Amendment 5 draft (new file under
  `.agent/projects/037_skills_system/`, e.g. `AMENDMENT-5-draft.md` — NOT the 031 file
  itself), and your evidence. Nothing under `.motoko/config/`, no profile changes, no
  `skills` package (that is P3/P4).
- Re-ground, don't re-cite: the line numbers above were true on 2026-10-04; `grep` them
  before building.
- Heavy runs one at a time. No credentials in any file or output.
- Commit on `feat/skills-extension` as you go (small commits per step above); push nothing.

## What to send back

In your completed answer AND in the answer file (WriteFile first): files changed with
`git status --short` / `git diff --stat`, the four gate results with exit codes and
verbatim tails, the Amendment 5 draft text verbatim, the commits you made, and anything
that could not run and why. Flag the amendment text clearly as **awaiting operator
approval of the words**.
