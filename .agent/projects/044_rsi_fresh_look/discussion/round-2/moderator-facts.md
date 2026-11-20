# moderator — facts settled after round 2

The moderator checked the two factual disputes raised in round 2 at HEAD `2eae0666`, with
AILANG v0.60.4. Settling them takes no position on any proposal.

## 1. Supply of historical faults

```
$ git log --no-merges --grep='^fix' --format=%h -- src/ packages/ | wc -l     -> 123
  of which the subject starts with "fix"                                     -> 111 (12 match only in the body)
  committed after 2026-08-01                                                 -> 80
  reverse-apply cleanly at HEAD, paths src/ and packages/ only
    (git show --format= C -- src/ packages/ | git apply --check -R -)       -> 34
  reverse-apply cleanly at HEAD, whole patch
    (git diff --binary C^ C | git apply --check -R -)                        -> 25
  the 25 driver-file fix commits of fable's round 1, clean reverse           -> 2   (fable and astra agree)
```

- fable's 34 and astra's 25 are both correct; they differ in which paths are reverted.
- neon's "43 commits across ~16–18 families" was not tested for clean reversal.
- The behavioural/non-behavioural split and the family counts (fable: ~14 behavioural in ~9
  families; astra: at least 6 distinct mechanisms) are judgements the moderator did not verify.
- **Consequence:** no design can count on more than 25–34 historical faults that inject cleanly
  at one commit, probably about 14 of them behavioural. Anything beyond that is hand-ported,
  planted or seeded.

## 2. The compile-cache limit (fable round 1 §4 item 1 and P2; neon round 2 §A)

- The 16 MiB limit was recorded on 2026-10-06 at AILANG `e939cba`
  (`.agent/projects/011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md:179-185`).
- The installed AILANG v0.60.4 has `maxArtifactBlobBytes int64 = 64 << 20`
  (`~/.local/share/ailang/internal/pipeline/cache_artifacts.go:38`). The CI comment says v0.52.2
  raised the cap (`.github/workflows/verify-extensions.yml:133-134`).
- `ailang check src/core/session.ail` in the clean worktree: **24.8 s** cold, **1.7 s** rerun, no
  `ARTIFACT_TOO_LARGE`. The module now caches.
- **Consequence:** "3.7 min per mutant because `session.ail` does not fit the cache" is obsolete.
  Today's per-mutant cost for the targeted gate set is unmeasured; the latest recorded figure is
  about 46 s for the judge tier (`014/NOTE-001`, cited by fable round 2).

## 3. Facts more than one participant verified

- m06 was scored `KILLED` on a crash with no summary
  (`.agent/projects/037_skills_system/evidence/p3/mutants.tsv:6`, `mutate.py:100`).
- `tools/eval_protected/manifest-A.json` is 872 commits stale; the check gives 20 findings and
  `REFUSED`.
- At HEAD the journal evaluator refuses every real entry (`scripts/eval/journal_replay.ail`).
- A comment-only system-prompt edit is not a null control: the model reads the prompt as text
  (astra round 2). A byte-identical rerun is.
