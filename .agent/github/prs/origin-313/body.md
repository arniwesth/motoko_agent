---
repo: arniwesth/motoko_agent
pr: 313
branch: arniwesth/041-d8-addition-is-not-a-bump
ticket: null
title: "docs: an added event variant is not an event-vocabulary bump"
---

## Summary

ADR-001 D6 says "a change to **any** variant, wire name, payload schema, or classification is a version change", and `src/core/dst_event_vocabulary.ail` repeats it. Read literally, that makes **adding** a variant a bump, and 041 W7 added `ToolArgumentsInvalid` at `event-vocabulary/4`. This PR qualifies the rule to an **existing** variant: the wording says "any", but the purpose is that no old trace is read by a vocabulary that cannot interpret it. **An addition cannot orphan an old trace**, because the trace cannot name a variant that did not exist when it was written. **A deletion can**: the trace names a variant the new code no longer has, and with no decoder nothing can skip it. **All three bumps to date were deletions** (`/2` `Dp7VerifierRejected`, `/3` `PersistNudge`, `/4` `HybridBashExtracted`).

Two citations are corrected. First, `ToolArgumentsUndecodable` (`8980ba61`, 2026-09-06) was added at `/1` while the rule was already in force (since `c8730020`, 2026-08-02), and the version was not bumped. Its commit does not discuss versioning, so it is an **unexamined instance, not a precedent**. The reasoned precedents are WI-A14 (no versioned surface touched) and now W7. Second, the bump condition was attributed to **D8**. It is **D6's**: D8 records the version and supplies the decode-or-pin rule that D6 adopts.

**No behaviour changed and there is no version bump. The version stays `event-vocabulary/4`.** The `.ail` change is comments only.

## Changes

- docs(core): an added event variant is not a vocabulary bump (041 W7)
- docs(009): amend D6 — adding a variant is not a version change (041 W7)

1. **`dst_event_vocabulary.ail`, the WI-A14 comment (~line 80):** "D8 makes a change to a variant" becomes "D6 makes a change to an EXISTING variant", with a pointer to the rule below.
2. **`dst_event_vocabulary.ail`, the rule above `event_vocabulary_version` (~line 119):** "D8's compatibility rule … any variant" becomes "D6's versioning rule … an EXISTING variant", keeping D8 for the decode-or-pin half. A new paragraph says why an addition is not a bump, that a bump is not free (`dst_profile.version_matches` refuses a drifted version with `ManifestVersionDrifted`), and the one cost of the qualifier: the reader of a `/N` trace is the **last** commit at `/N`, which is what each existing pin already names.
3. **ADR-001 D6 amendment**, appended directly after the clause it amends (ADR:2239–2241), following the ADR's convention. The clause itself is not edited. The amendment states the qualified rule and the reasoning, and corrects the two citations above: the `ToolArgumentsUndecodable` precedent and the D8/D6 attribution in the WI-A14 amendment (ADR:2211). The WI-A14 sentence is not rewritten in place.

2 files changed.

## Governing docs

- `.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`

## Predicted outcome

The next added `LedgerEvent` variant is made at the current version without debate, and the next deletion bumps it. Nothing observable changes now. Checked below: the vocabulary DST still passes at `/4` with 43 rows, and `src/core/` still type-checks.

## Test evidence

**1. Files changed.** `git diff --name-only origin/main...HEAD`:

```
.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md
src/core/dst_event_vocabulary.ail
```

**2. Every changed `.ail` line is a `--` comment.** Changed lines not starting with `--`:

```
$ git diff -U0 origin/main...HEAD -- src/core/dst_event_vocabulary.ail | grep -E "^(\+|-)" | grep -vE "^(\+\+\+|---)" | grep -vc "^[-+]--"
0
```

**3. The version is unchanged.**

```
$ grep -n 'export pure func event_vocabulary_version' src/core/dst_event_vocabulary.ail
161:export pure func event_vocabulary_version() -> string { "event-vocabulary/4" }
```

**4. `make event_vocabulary`** (`env -u AILANG_FS_SANDBOX`, via `setsid`):

```
=== event_vocabulary_dst (D6, event-vocabulary/4) ===
event_vocabulary_dst PASS
  ✓ 43 LedgerEvent variants == 43 vocabulary rows == 43 golden-pinned variants
exit=0
```

**5. `make check_core`** (via `setsid`):

```
src/core/ type-check: 61 passed, 0 failed
exit=0
```

**6. The unqualified wording.** It is gone from the `.ail` file:

```
$ grep -c "any variant" src/core/dst_event_vocabulary.ail
0
```

The one ADR hit is D6's original clause. It is deliberately left in place, with the amendment directly below it:

```
$ grep -n "A change to any variant" ADR-001-deterministic-test-world-architecture.md
2239:four axes. A change to any variant, wire name, payload schema, or classification is a version
```

**7. The amendment's location.** ADR lines 2243–2275, between D6's clause (ending at 2241, "…decoding or pin a runner, never silently reinterpret.") and `### D7. Invariants are evaluated over the whole execution` (2277).

Both runs also printed the existing `sunholo/motoko_ext_skills content changed … Run 'ailang lock'` warning. It is unrelated to this PR.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
