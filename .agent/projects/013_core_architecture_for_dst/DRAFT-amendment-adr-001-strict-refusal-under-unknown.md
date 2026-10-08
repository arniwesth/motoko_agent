# DRAFT amendment to ADR-001 D1 — under `extensions.strict`, a compactor whose model has no window refuses to start

**STATUS: DRAFTED, NOT APPLIED.** Nothing in this file has been written into
`ADR-001-sequencing-the-dst-architecture-caps.md`. It is offered for the operator's acceptance,
rewording or rejection. Written on 2026-10-08 against `bb4424fe` plus PR #239
(`fix/237-unknown-limit-visible`), where the behaviour it records is implemented.

**Why an amendment and not an edit.** ADR-001 considered refusing under `Unknown` and rejected it
(Options considered, option 4: "loud, not blocking"). It then listed "behaviour under `Unknown`
beyond loudness" under Not decided, as needing "an owner's number". PR #239 adds a refusal. It is
narrower than the one the ADR rejected, and the operator asked for it, but until this is applied
the governing document describes behaviour the code no longer has. The Codex Sol review of #239
(2026-10-08) raised exactly that.

Two amendments. **A** records the decision. **B** corrects one sentence of D1 rule 2 that **A**
would otherwise cite as still pending. They can be accepted separately.

---

## Amendment A — a strict profile with a compactor does not start on an unknown limit

*Proposed insertion points: `ADR-001:251–253`, after the sentence that ends option 4 ("…loud, not
blocking."), as a dated note; and `ADR-001:638–639`, replacing the first bullet of Not decided.*

Proposed note after option 4:

> **Amendment, 2026-10-08 (PR #239).** One refusal under `Unknown` now exists, and it is not
> option 4. When the profile sets `extensions.strict`, at least one registered extension carries a
> `Compactor` atom, and the run's limit resolves `Unknown`, the launcher emits one `error`
> (`error_code: strict_context_limit_unknown`, naming the model, both misses and the compactors)
> and exits 2. It differs from option 4 in three ways, and each removes a ground on which option 4
> was rejected:
>
> - **It is opt-in.** Option 4 was rejected because it would have stopped runs that work today
>   (2 of 14 profiles set an override, 23 catalogue rows, an uncatalogued model run for a full
>   session in NOTE-008). `extensions.strict` is `false` in 16 of 16 shipped profiles, so no run
>   that starts today is stopped. Re-measured the same day: 2 of 16 profiles set an override and
>   the catalogue has 29 rows.
> - **It is conditional on a compactor.** It is not a rule about measurement. It is the existing
>   meaning of `extensions.strict`, "a profile may not run with less than it declares"
>   (`registry_generated.ail`: an uninstalled name, an empty registration), applied to a compactor
>   that is installed and registered and can never trigger, because both shipped compactors take a
>   percentage of the window and `Unknown` hands them 0.
> - **It is a refusal to start.** It is asked where the run's model becomes known: at boot, at the
>   first task if a `model_change` arrived before it, and on a resume. A `model_change` after the
>   start is not refused.
>
> `Disabled` is not refused. It is declared in the profile (rule 3), so the profile already says
> what it runs with.
>
> For every profile that is not strict, D1 stands as written: `Unknown` is loud and not blocking.

Proposed replacement for the first bullet of Not decided:

> - **Behaviour under `Unknown`** beyond loudness, for a profile that is not strict. Decided for
>   strict profiles with a compactor on 2026-10-08 (see the note at option 4). Still open: whether
>   a run may assume a window when none resolves (issue #237's suggestion 2, not taken:
>   `docs/configuration.md` says the limit is not guessed), whether a `model_change` to a model
>   with no window should be refused once a run has started, and whether the measurement boundary
>   should ever be blocking in 028 ADR-001's sense. Needs an owner's number.

**What stands behind it.** The operator, in the session that produced #239. Asked whether to
"refuse to start under `extensions.strict` when a compactor is loaded and the limit is unknown",
and then whether it belonged in that PR or a follow-up, the answer was: "Yes, strict refusal in
same PR". The scope above (compactor only, start only, `Disabled` exempt) was proposed by the
implementing session and has not been ruled on line by line. Accepting this amendment is that
ruling.

**The gate.** `make verify_strict_context_limit`, in `check_core`: six arms over three runs. Each
of seven mutants of the refusal turned the arm named for its rule red, and no arm before it
(#239, Test evidence). Two of the three call sites, the first-task one and the resume one, have
no arm.

**A limitation to record with it.** The refusal is decided on the limit the session will use,
which the resolver reads from `$MOTOKO_PROFILE_DIR/config.json`, and not on the configuration the
loader loaded. Where those differ the decision is still right (the run would not compact) and the
stated reason is wrong. PR #241 removes the case a normal launch can reach, the legacy flat
`.motoko/config.json`. A hand-run `supervisor.ail` with no `MOTOKO_PROFILE_DIR` remains.

---

## Amendment B — rule 2's TypeScript follow-up names a counter that no longer renders

*Proposed insertion point: `ADR-001:334–335`, after the sentence "Rendering "unmeasured" in the
TUI counter is a TypeScript follow-up, named, not done here."*

> **Amendment, 2026-10-08 (PR #239).** The follow-up is done in a different place from the one
> named, and the place named cannot carry it. The TUI's context counter reads a `context_usage`
> event that the runtime has not emitted since `6350b7ad`, so there is no live counter to render
> "unmeasured" in. What reached the operator instead is a `warning` raised by the host from the
> `unknown` arm of `ContextLimitResolved`, once per distinct model and pair of misses: in the TUI
> history, on the JSONL wire, in the transcript, and on plain headless stderr. Until #239 nothing
> in the host read that record, so rule 2's "visible … once per run" held on the wire and for no
> person.

This changes no decision. It corrects where the visibility D1 promised actually lands, and it
records that the counter is dead, which this ADR's text assumed it was not.

---

## What is asked of the operator

1. Accept, reword or reject **A**, including its three limits: a compactor must be registered, the
   refusal is at start only, and `Disabled` is exempt.
2. Accept or reject **B**.
3. Say whether the ADR's header should change. It still reads "Proposed (v3)", and D1 has been
   implemented since PLAN-001 P1A to P1C. That is outside this draft.
