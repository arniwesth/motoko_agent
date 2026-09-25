# DIRECTIVE 2026-09-19 20:2xZ — P2.2 reads `done` but STOPPED; lock_root driver defect returned to the operator

By: observer (w3:pZ), under the `run.observer` grant of 2026-09-19T17:46:16Z.
Scope: P2.2 / P2.3, PLAN-004 v2.
Authority: **mixed** — §1 is `may_decide_and_continue` (grant scope: "correction of run-file state
that its own receipts contradict"). §2 is `recommend_and_return` (grant return: "authorizing a new
fix set, reviewed code part, or evaluator (E) re-pin"). **Operator ruling on §2: pending.**

## 1. Correction — P2.2 is not `done` (in scope)

`P2.2` projects to `done` from `a14`, which settled `done` at 19:30Z. Its own receipt
(`answer-mot-dlg-1789847872818.md`) is titled **"STOP REPORT"** and says:

> *"STOPPED per directive — candidate assembly still yields `a_path=None` for every path package;
> no workaround attempted; escalates to driver change."*
> *"No repeat tables and no tolerance/peak/gate proposal exist — there were no verdict-path runs to
> tabulate."*

P2.2's criteria require 1 warm-up + 3× Reproduced + 3× Diverged per segment and a
deviation/tolerance/peak/gate proposal in §6. None of that ran. **Set `P2.2` to `blocked`**, with:

```
unblock: operator ruling on the candidate-assembly lock_root defect (candidate.py:566 lock_path_rel
         / :620 copy_path_packages); a driver change implies a new E and re-pin
```

Also: `a13` and `a14` carry `progress: null`, and `a13`'s `cause.reason` is the extension's
auto-seeded `"delegated again against the operator's plan"` — the string that made the original
twelve-attempt alias ring unreadable. Annotate it and emit `progress` on both, as P2.3 now does.

**This is the fourth instance of this projection error** (P2.3 at 06:39Z, 09:22Z, 11:37Z; now P2.2).
It is the first entry on the detector list: diff `progress.done` against the ledger row count, and
refuse the settle rather than correcting it afterwards.

## 2. Return — the lock_root defect needs an operator ruling

**Do not fix this under the current E.** Returned because a driver change to `candidate.py` is
evaluator bytes and implies a new E and re-pin, both on the observer's return list.

Confirmed in `A` at E `562acadc`:

```python
candidate.py:566  def lock_path_rel(path, lock_root):
                      root = os.path.normpath(lock_root)
                      if not (path == root or path.startswith(root + os.sep)):
                          return None          # ← all 22 path packages land here
candidate.py:620  copy_path_packages(repo, a_commit, lock, lock_root, pkg_root)
                      rel = lock_path_rel(p.get("path", ""), lock_root)
candidate.py:1227 pins = {… "lock_root": os.path.normpath(lock_root) …}
```

The delegate reports the mismatch is **invocation-independent — verified**, i.e. not a matter of how
the driver was called. So `lock_root` and the `path` entries in `ailang.lock` are genuinely
inconsistent, and every path package is silently dropped rather than refused. That silence is itself
worth a finding: `copy_path_packages` treats "outside the root" as "skip", so a total assembly
failure presents as an empty copy rather than an error.

**What the operator is asked to rule:** whether to authorize a driver fix (new fix set → new E →
re-pin → MATRIX regen), and if so whether `lock_root` should be derived from the lock's own paths or
the lock paths normalised against `A`. Options and a recommendation belong in the packet, not in an
implementation.

## 3. What P2.2 did achieve — do not lose this in the STOP

The same receipt records the furthest this task has ever reached, and it should lead the packet:

- **Both real prefixes admitted `SourceFaithful`** at new E `562acadc` — the 57-call maximal prefix
  (`CutoffBefore(0179)`, `EndSuspended(57)`) and the independently checked ≈N/2 28-call prefix
  (`CutoffBefore(0088)`, `EndSuspended(28)`). That is P2.2's selector criterion met.
- E-record `.motoko/eval-corpus/_g2/e-record-562acadc.json` attested; 23 packages + dot-pin.
- `A` clean at every gate, nothing staged, no commits, no MATRIX regen.

Blocker B1 of 2026-09-17 — *"the runner has NO real-entry path"* — is cleared in practice. The
remaining block is downstream of admission, in assembly.

## 4. Bookkeeping

- `generated_at` was `14:09:25Z` for ~4 hours against writes at 18:00; now `20:13:43Z`. Refresh on
  every write.
- **No `directive` event has been appended since 2026-09-19T08:04Z.** Nine directives and the G2
  grant are absent from the decisions log. From this one on, append
  `{"type":"directive","by":"observer","verb":…,"task":…,"detail":"<path>"}` — `by: "observer"`,
  not `operator`, and it passes `dagr check --strict`.
