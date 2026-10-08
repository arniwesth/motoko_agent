# Observing `make demo_dst`

Run date: 2026-10-04. Source HEAD at launch: `cf54dff9`; the workspace already
contained unrelated edits, including to the Makefile. The demo's target file,
`src/core/session.ail`, was clean. This is a working-tree observation, not a
clean-checkout reproduction claim.

Outcome: `make demo_dst` exited 0. The runtime reported `finish_reason=stop`, no
error, 12 completed provider calls, and `duration_ms=1009969` (about 16m50s,
excluding launcher startup). This was longer than the prompt's ten-minute framing.

## What was run

```bash
env -u MODEL MOTOKO_HEADLESS=1 TERM=xterm make demo_dst
```

Removing an inherited `MODEL` override let the `demo_dst` profile select
`openrouter/xiaomi/mimo-v2.6-pro`. The default audience number was 42. The launcher
used its normal live model to conduct the demonstration; the DST subprocesses used
simulated model responses. Deterministic test execution does not make the outer
model's narration or command timing deterministic.

The target supplies a detailed [demo prompt](../.agent/notes/DEMO-dst-self-test-prompt.md)
to Motoko. The model executes the prescribed shell commands, reads their results,
and explains them. Its commands are recorded as `BashExec` calls. This run did not
use herdr delegation to conduct the demonstration.

Selected actual tool output is retained in
[the evidence extract](evidence/demo-dst-2026-10-04.txt). It excludes model narration
so that observations can be distinguished from the model's account of them.

## What happened

The seeded-generator checks passed. Seed 132 produced 24 interactions and digest
`864106749` on both repetitions. Seed 12 also produced 24 interactions, but digest
`484525277`. This exercises both repeatability and sensitivity to the seed without
relying on a difference in interaction counts. A negative control also detects a
generator that ignores its requested seed.

Audience number 42 selected seeds 13–16 under `driver_only/32`. The two separate
baseline processes produced matching program identities. Seed 13 exercised approval
denial, seed 15 exercised a tool deadline and approval denial, and seeds 14 and 16
reported no injected fault classes. A four-seed demonstration does not establish
coverage of every catalogued fault.

Motoko then made exactly the intended one-line change in `session_policy_init`:

```diff
- let r_base = ports.env_get(advance(r_retry.next_state, EnvRead), "OPENAI_BASE_URL", "");
+ let r_base = ports.env_get(advance(r_persist.next_state, EnvRead), "OPENAI_BASE_URL", "");
```

Each modeled environment read returns a value and an updated world. The second
read obtains `MOTOKO_RETRY_STREAM_ERROR`; its successor carries the record of that
read. Starting the third read from the first read's successor discards that record.
The value used to configure retry behavior is still available. Both successors
have the same type, so the compiler accepts the edit.

The running Motoko process continued conducting the demo. Subsequent test
subprocesses loaded the edited source; this was not a hot replacement of the
already-running driver's code.

## Observed scorecard

The clean type check and clean replay gate were observed after restoration. The
initial and restored corpus identities matched.

| Check | Clean/restored source | Deliberately defective source |
|---|---|---|
| Type check | `No errors found!` | `No errors found!` |
| Four-seed rotating corpus | Pass, exit 0 | Pass, exit 0 |
| Program identity, seed 13 (12-character display prefix) | `8d3fbc7641b5` | `be867c5e62bf` |
| Rich scenario outcome | `Ok` | `Ok` |
| Replay matches recorded interactions and terminal outcome | Pass | Pass |
| Rich scenario recorded interaction count | 31 | 30 |
| Recording completeness assertion | Pass | Missing environment read detected |
| `make strict_replay` | Pass, exit 0 | Fail, exit 2 |

All four displayed identities changed under the mutation and returned to baseline
after restoration. Changed identities show changed recorded behavior; alone they
cannot distinguish a defect from an intentional implementation change.

The decisive diagnostic was:

```text
[discovery-env-read-under-recorded] this scenario's control flow reaches 1 read(s) of 'MOTOKO_RETRY_STREAM_ERROR' and the log records 0
```

The distinction inside `make strict_replay` matters. Comparing the original
recording with its replay passes because both runs lose the same observation.
The separate completeness assertion compares the recording with an expected read
count derived from source and scenario control flow. That expectation is not
produced by the recorder, but it is also not a runtime trap independently counting
environment reads. The diagnostic explicitly states that limitation.

The shell command running the mutant gate returned 0 because it printed and
filtered the results after `make` failed. Its printed `exit=2` and
`strict_replay_dst FAIL` are the gate's verdict. The successful tool-wrapper exit
must not be mistaken for a successful test.

Motoko reversed its edit without requiring a checkout. An independent comparison
against a pre-run backup confirmed byte-for-byte restoration. The original and
restored source SHA-256 was:

```text
33151b8a570df892554aa0799170f71376767098238d4811adf9cee173e7ba9e
```

## Coverage and operational observations

The final fault-catalogue check passed, reporting 11 required classes and four
remaining coverage gaps: an internally inconsistent provider result, adversarial
partial-stream behavior, a clock-driven approval deadline, and additional kinds of
extension effects. These are qualified gaps in the catalogue's report, not a claim
that those entire broad areas have no tests. The exercised profile installs no
extensions, so its success does not establish extension-effect coverage.

Two practical details matter for reproducing or presenting this demo:

- The target clears a shared `/tmp/motoko-dst-demo` directory and edits the shared
  driver source. Another session had already launched a demo when this one began;
  this launch cleared its temporary artifacts. That session stopped its run before
  either run reached the mutation. Only this run remained at the mutation step.
  The target needs exclusive use of those paths; its clean-file preflight does not
  provide a concurrency lock.
- After the scripted closing response, the profile automatically invokes
  `make check_core`. This is additional work beyond the prompt's numbered acts and
  adds to the end-to-end runtime. The scripted tests and source restoration had
  completed before this finalization check began. The process subsequently exited
  successfully without a verifier rejection event. The verifier's output was not
  surfaced in the session log, so this note does not claim a separately observed
  `check_core` pass; the finalization implementation also has fail-open paths.

## Use in the blog post

This demonstrates Motoko operating its own development and testing tools, including
a controlled edit to its source. The defect and the command sequence are supplied
in the prompt; it is not evidence of autonomous bug discovery or arbitrary repair.

The strongest scene is the moment a reproducible, apparently successful execution
fails the independent completeness assertion. It gives the reader a concrete
reason why a software factory needs more than repeatable runs and reassuring
completion messages. It also connects the ambition of RSI with the immediate work
of making checks meaningful and the factory reliable.
