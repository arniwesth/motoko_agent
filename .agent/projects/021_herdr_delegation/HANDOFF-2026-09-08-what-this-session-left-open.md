# Handoff, 2026-09-08: what 29 commits did, and the eight things they left open

Supersedes [`HANDOFF-2026-09-03`](HANDOFF-2026-09-03-patch-state-and-what-remains.md) as the
current status doc. That one is still correct about the patches; it is five days and 29 commits
stale about everything else.

Branch `arniwesth/021-herdr-delegation-remaining`, `b8d6a7b`..`0cabdf4`, **10 unpushed**.
All gates green at HEAD (`check_core` 58/58, `profile_definition`, `profile_coverage`, and the
eight DST targets).

---

## 1. What was built

Grouped, because the commit list reads as one thing per line and it was not one thing.

**The ABI, three times, because it was about to freeze.** 7.1 added `PublishFileAction`
(`{tmp, dest, expect_sha256}`); 7.2 added `ExtCtx.finish_reason`; 7.3 added `WorkItem` /
`WorkOutcome` / `WorkInFlight`. Now at **7.3** and re-locked.

Two things worth carrying forward from how those went. `ExitAction.PublishFile` was described as
existing by [`DESIGN-exit-intent-abi`](DESIGN-exit-intent-abi.md):40 and did not — the 7.0 security
pass had deleted it, and the doc was never updated. And the publish verb was nearly built on
`expect_bytes`, which would have been silently wrong: AILANG's `length` counts **runes**, so
`length("æøå") == 3` where the byte count is 6. It is a sha256 digest instead, verified to agree
byte-for-byte between AILANG and Node on UTF-8.

**herdr's delegation surface.** Settle-on-exit; a startup sweep that repairs the records it can
only report on; a bounded prompt retry; model transport to a motoko delegate (`--env MODEL=`);
`publish` now validates through `dagr check --strict` before renaming.

**The measurement that changed a design.** [`MEASUREMENTS-2026-09-07`](MEASUREMENTS-2026-09-07-prompt-delivery.md)
ran §3.1 against live herdr 0.8.2: an `agent_not_ready` refusal delivers **nothing** (4/4, pane
byte-identical), which licensed the retry. The **control case** was the surprise — a *detected*
claude accepted and executed a prompt, proving the extension's own error text ("Only agents started
with `agent start` are promptable") false. herdr's rule is the NAME binding. The text is corrected.

**DST.** A fourth profile, `driver_plus_herdr` — the first to cover a TOOL rather than only hooks —
plus the discovery chain that makes the graded herdr run evidence rather than a demo.

**dagr.** Forked to `motoko-agent/herdr-dagr`, branch `apply-command`, and given a write verb
(`dagr apply`, RFC 6902) so a run file can have a second producer. Pushed, **no PR**, deliberately.

**Filed upstream:** three AILANG tickets — `fb_cc1cb8fb23e1ead1` (output cap),
`fb_334b4d8dea088ada` (composite expected values), `fb_0a8ab94817a74c3e` (imported effectful
reference). Nothing filed against herdr; see item 6.

---

## 2. Open: `exercised_fault_classes` is empty in two profiles

`src/core/dst_driver_plus_herdr.ail`:368 and `dst_driver_plus_compose.ail`:721.

[`NOTE-2026-09-03`](NOTE-2026-09-03-herdr-under-dst.md) §7 step 2 asks for the
`extension_effect_fault` waiver to be dropped and a fault row injecting a **failing `pane split`**.
The graded fixture could express it — its second entry is the split's answer — but no run exercises
it, and the profile record says so in place rather than claiming the class.

That refusal is the point and should survive: naming a class with no run behind it is the same
error a deleted draft made about `discovery`. **The work is the run, not the record.**

## 3. Open: `validate_manifest` never checks `abi_version`

`src/core/dst_profile.ail`:1535 gives `abi_version` a **presence** check and no equality check,
while five sibling version fields get `version_matches` against their live value. No comment
explains the asymmetry, in a function that justifies its other weakening at 18 lines' length.

The tell is in the module's own `fixture_manifest()`: every field under a `version_matches` rule is
written as a live CALL, every field without one drifted to a stale LITERAL.

`0cabdf4` widened the Python guard (`check_abi_version`) from a naming convention to the defect
class and repaired **eleven** stale `4.0` pins. That is a backstop, not the fix. The fix needs the
ABI version **exported from `packages/motoko-ext-abi` as a function** — it is declared only in that
package's `ailang.toml`, which no AILANG module can read. That is an ABI-package change during a
freeze, so it is a decision, not a chore.

## 4. Open: the `toolchain` pin, which is NOT the same defect

**22 sites across 17 files**, 21 saying `"ailang 0.33.0"`. Twice the ABI pin population, spanning
six files whose ABI pins were already correct. Two fields — `toolchain` on `ExecutionManifest` and
`toolchain_version` on `ReplayMetadata` — already linked by a projection invariant
(`replay_metadata_of`, tested at `dst_profile.ail`:2237), so the tree enforces internal consistency
and has no external anchor.

Three reasons the ABI recipe does not transfer:

1. **No single source of truth.** `ailang.toml` says `ailang = ">=0.33.0"` (a constraint);
   `ailang.lock` and `ailang --version` both say `v0.33.1-85-gde5a141e4-dirty`. The recorded string
   matches **none** of them and looks derived from the constraint floor. No site records the
   toolchain that actually produced these runs.
2. **The sweep has been tried and has a casualty.** `scripts/dst/program_persistence_dst.ail`:605
   documents WI-B4 sweeping 14 stale `0.26.0` strings and rewriting a **frozen v1 specimen** with
   them. That gate went red correctly — a frozen artifact's toolchain is part of the specimen, not
   a claim about now. It is pinned at `0.26.0` forever with *Do not "update" it with the others*.
   So a guard here needs a derived exemption the ABI guard never needed.
3. **Pinning it truthfully broadcasts the dirty build.** The correct value for a reproducibility
   manifest is the binary that produced the run, which today is a dev build (see item 8).

**Order matters and is the opposite of the ABI case.** Fix the toolchain story first; only then does
the pin have a value worth guarding. Guarding now produces a green gate asserting a fiction.

## 5. Open: step 1 of the DST note is half done

[`NOTE-2026-09-03`](NOTE-2026-09-03-herdr-under-dst.md) §7 step 1 has two halves. The **fixture**
half is done — `1bcbbc1` replaced five hand-rolled scripted herdrs with `src/core/test/herdr_fixture.ail`
(10 shared helpers, 185 lines deleted). Port stubs were deliberately NOT shared, because of the
effect-row asymmetry between them.

The **registration** half is open: re-register the cases of `verify_mot133_owner_tag.ail` and
`verify_mot136_dagr_producer.ail` as `dst_harness` scenarios with dotted ids under one
`scripts/dst/herdr_l1_dst.ail`, chained into `DST_TARGETS`. (The note says 16; this session added
retry cases and the numbering is no longer contiguous, so count them rather than trusting either
number.)

**A reservation, recorded because it is mine and unverified.** The note sells this as buying
`scenario=`/`seed=`/`trace` reporting plus the anti-silent-drop count. The count oracle is real
value. The rest I am less sure of: these are deterministic scripted transcripts with no RNG axis,
so `seed=` may buy nothing and the trace would be over scripted input. **Re-derive this before
doing the work** — if the reservation holds, the item shrinks to just the count oracle.

## 6. Open: finding C's evidence capture

Settled 2026-09-08 in [`DECISION-2026-09-08-finding-c-upstream.md`](DECISION-2026-09-08-finding-c-upstream.md):
**do not file**. The tracker search found the mechanism (`agent prompt` gates on identifying the
pane **foreground process**; #3397 reports our exact string on 0.8.2, deduped into a Windows-only
fix) and three reasons a filing would not land — not reproducible, 0.8.2 while stable is 0.9.0, and
we lack the diagnostic the maintainer asks for.

**The actionable part:** `herdr pane process-info` exists on 0.8.2. Capture it on the final
`agent_not_ready`, **before the failure branch's `pane close`** — that ordering constraint is what
makes it a real change rather than a logging line. Then the next occurrence files itself.

## 7. Open: run-file growth

[`DESIGN-dagr-as-delegation-view`](DESIGN-dagr-as-delegation-view.md):349 — the whole file is
rewritten on each write, so *n* settlements write O(n²) bytes, and the coefficient is now 2. Fine
for a dozen delegates, not for a long-lived orchestrator. **Needs a cap or rotation decision**
before anything runs unattended.

## 8. Open: two container facts that are not code

- **`ailang.lock` was generated by a dev build**, `v0.33.1-85-gde5a141e4-dirty`. This is item 4's
  blocker, not a separate nit.
- **Rust 1.98.1 is at `~/.cargo` and not in the Dockerfile.** It was installed to build the dagr
  fork, so the fork does not rebuild in a fresh container.

---

## Constraints for whoever picks this up

**Never stage another session's files.** A second agent is working in this tree. At HEAD that is
`.agent/projects/013_*`, `.agent/projects/028_*`, `.motoko/model-catalog.json`, `.motoko/ab/`,
`ailang.lock`, `src/tui/src/models.test.ts`, `docs/`, `little-coder/`. Check `git status` before
every `git add`, and stage by explicit path.

**Falsify before believing a gate.** This session found holes six times, mostly in tests written
minutes earlier: a settle case that passed with the knob ignored; a prune case that passed without
its liveness guard; a retry case that passed by never refusing at all; a prose guard naming the
wrong slot; a seeding idempotence guard that passed twice; and two gates that could not fail the
build at all (`|| (echo … && exit 1)` in a subshell without `set -e`, and a pipe to
`grep -E '^(OK|FAIL)'` which succeeds ON a FAIL line).

**Back up before falsifying.** One falsification loop used `git checkout --` and destroyed
uncommitted work that had to be rewritten. Every other one used a scratchpad copy. Use the copy.

**`make check_core` does not cover the DST profiles.** `driver_plus_compose` was broken at `d20e048`
and not noticed until `ac44060`. Run the profile targets explicitly after an ABI change.
