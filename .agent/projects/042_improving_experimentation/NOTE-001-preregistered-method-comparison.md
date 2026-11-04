# Running a pre-registered comparison of two methods

Date: 2026-11-04

Status: A protocol extracted from project 043's trial (`PLAN-001`), which is in progress. As of
this date it has been run through planting, sealing and the first batch of arm sessions, not to a
result. Whether it produces good decisions is not yet shown.

The [research direction](RESEARCH-improving-experimentation.md) asks for incumbent and candidate
methods to be compared "on fresh tasks", with the evidence kept credible, and leaves the budget,
acceptance criteria and stopping conditions to be specified before a pilot runs. Project 043
needed exactly that to decide whether proofs in Lean find defects that executed checks on the real
code miss. This note extracts what it built, so the next comparison does not start from scratch:
first the protocol, then what running it on this machine taught.

## When it is worth it

Use it when a choice between two methods will change what gets built, and argument will not
settle it. 043's trial costs one planter session (about 70 minutes), 24 arm sessions of 2 hours
in three batches, an adjudication pass, and the operator's time at approval, sealing and
decryption. A question that one differential run can answer does not need it.

## The protocol

Each part prevents a specific way a comparison misleads.

**1. Two named hypotheses.** One says the new method wins (043: H-L, "Lean finds what executed
checks miss"), one says it does not (H-D). *Prevents* a question that no outcome can answer.

**2. A decision rule fixed before the answer key exists.** Name the outcomes (043: L, D, X), the
thresholds that select each, what each commits the project to, and the conditions that void the
trial. *Prevents* choosing the conclusion after seeing the results.

**3. Predictions with probabilities.** The proposer writes down the expected outcome and its
probability (043: D at 0.60, L 0.25, X 0.15) in a separate file. *Makes* the proposer's bias
visible and lets later trials check calibration.

**4. Freeze by hash, then log everything.** The plan and the predictions are hashed into an
append-only `sequence.log`, together with the approval. Before the answer key exists, a change is
a dated amendment appended to the plan, with a new hash line. After that, nothing in the plan
changes: a departure is a deviation, logged when it happens and reported with the results. The
scripts are hashed too, at every change. *Prevents* silent changes and leaves an audit trail.

**5. Arms that differ only in method.** Same model, effort, wall-clock budget and tools. Each
arm's brief is written into the plan verbatim, and the brief is the only thing the arm is told.
Two or more replicates per arm per target, because live model runs vary. *Prevents* comparing a
method with a budget, a model or a prompt.

**6. An answer key made by someone else and sealed.** A separate planter session plants defects
and never sees an arm's work. 043's rules for each seed:
- One plausible slip of at most 3 changed lines, from a fixed operator vocabulary.
- Every existing gate stays green, since a seed a gate catches tests nothing.
- A concrete witness per seed, with its size.

Seeds come in classes, and the plan says which class carries the hypothesis. In 043, S2 seeds
have a smallest witness beyond the small bound an arm can enumerate, and the planter logs an
exhaustive search showing it. The E class are behaviour-preserving refactors: a trap for false
reports.

Defects already known before the trial are listed in the plan, so an arm cannot score them as
discoveries. The answer key is encrypted under a passphrase only the human operator holds and
types; no session ever sees it. Its hashes go into the log before any arm starts: the manifest's,
the encrypted file's and the seeded tree's. At the end the operator decrypts, and the hashes are
checked. *Prevents* arms finding seeds by looking them up, and anyone editing the key after
seeing results.

**7. Blinding: enforced where possible, audited where not.**
- **The arms' tree.** It is built from a pinned commit, without the plan, the trial's records,
  or the repository's agent instructions.
- **Per-session settings.** Each session's settings deny reads of the repository checkouts,
  the other sessions' directories, the sealed material, and Claude Code's own records, and deny
  `git`. The brief also tells the arm to stay inside its two directories.
- **The audit.** Afterwards, a script audits every arm transcript. It sorts each tool call that
  touches a denied location into a breach, a refused attempt (which revealed nothing), or a note
  for the adjudicator.
- **Voiding.** A breach voids that session's results, and more than one voided session in an
  arm voids the trial.

*Prevents* an arm seeing the key, the plan, or another arm's work.

**8. Mechanical scoring.** Every report carries one reproduction command that exits 1 when the
defect is present and 0 when it is absent. A report detects seed `s` iff its reproduction exits 1
on the seeded tree `T` and 0 on `T−s`. A real defect exits 1 on `T` and on the unseeded base.
Anything else is classified by fixed rules:
- **Error:** a timeout or any other exit code. It is not a detection.
- **Unreproduced:** a report with no reproduction is neither a detection nor a false report.

Judgement is left only where it cannot be avoided: whether two reports are the same defect, and
whether an unknown real defect is reachable. It is written down with its reason. *Prevents* the
adjudicator's view of the methods from leaking into the score.

**9. A dry run that does not count.** Before the planter starts, run one short session per arm on
the unseeded tree. *Tests* the plumbing. 043's 20-minute dry run led to four fixes. It also found
three real defects (K8–K10), which went into the known-defects list instead of being scored later
as discoveries.

Outcomes are reported in the research direction's dimensions (useful findings, incorrect
conclusions, misses, investigation cost, human involvement, transfer, development cost), per arm
and per replicate.

### Against "Keeping the evidence credible"

| Principle in the research direction | Mechanism here |
|---|---|
| Separate development from evaluation | Planter, arms and adjudicator are separate sessions; the key is sealed; arms never read the plan |
| Include valid cases | E seeds, and false reports counted separately at their locations |
| Test transfer beyond new seeds | **Not covered.** One codebase and one planter. A stated limit |
| Keep model changes separate | One pinned model and effort for every session |
| Respect the limits of replay | Every arm session is live; nothing is replayed |
| Version the basis of acceptance | Pinned base commit; hashes of plan, predictions, scripts, trees and outputs in `sequence.log` |

## What running it taught

These are specific to Claude Code sessions in herdr on this devcontainer, and each cost time in
043.

| Problem | What happened in 043 | What to do |
|---|---|---|
| Deny rules are not a sandbox | Claude Code's `permissions.deny` blocks its Read tool and commands that name a path. It does not block a program that reads the path at run time | Encrypt whatever must stay secret; audit the rest |
| Leaks you do not think of | Found before any arm ran:<br>• other sessions' screens, through `herdr`<br>• the public upstream code, since a diff against it reveals every seed<br>• jest's transform cache in `/tmp`, holding compiled seeded code<br>• the planter's scratchpad<br>• a sibling session pushing to the same branch, so a tree built from `HEAD` would have changed | List the channels before the trial starts. Deny `herdr`, the web, `curl`, `wget` and `gh` to the arms, and have the audit flag them. Build the arms' tree from a pinned commit. Search for files written while the planter ran, and delete them with its plaintext |
| The operator reading the planter's screen | It would unblind the operator | Brief the planter to ask nothing, keep its choices in private notes, and end with one fixed line |
| Typing the passphrase | A `!` command in Claude Code has no terminal for openssl's prompt | Use a plain shell tab with no agent in it. Check by decrypting once before the plaintext is deleted |
| Claude Code's first start in a new directory | Its folder-trust prompt blocked the first dry-run session | The launch script answers it, for trial directories only |
| Background jobs outlive the cap | A dry-run arm left a job running after its stop | At the cap: interrupt, kill every process in the session's directory, then hash the output |
| The operator's session is not durable | The clocks ran as background tasks of the operator's session and died with it | Run clocks and watchdogs detached (`setsid`), logging to files |
| A restart drops the arms' flags | After a container restart, herdr resumed every Claude Code session with a bare `claude --resume`, without its deny rules or permission mode | After any restart, end the resumed arm sessions before anything reaches them |
| Eight sessions at once | They froze the container within 7 minutes. Its swap is zram, which thrashes instead of letting the kernel kill one process. The batch was lost | Run a memory watchdog with one rule for both arms: kill an arm's process over 6 GiB, and the largest one while available memory is under 3 GiB. Sample memory and load. Do not restart the container while a batch runs |
| No rule for an interrupted batch | The plan had none, so the operator decided as a deviation: the batch was relaunched fresh and the lost attempt not scored | Write the rule into the plan: what counts as an interruption, and what happens to the lost sessions |

## A lighter version

When the full protocol is too heavy, keep the four parts the result depends on:
1. The decision rule and the predictions, hashed before any run.
2. Arms that differ only in method, with replicates.
3. An answer key the arms cannot read.
4. Scoring by reproduction.

Fewer targets and a single batch cut most of the cost. A dry run is still cheap insurance.

## Where it falls short of the research direction

- **It covers only the comparison step.** It compares two fixed methods. The research direction
  wants a successor method that Motoko proposes and implements, and then a comparison of
  improvement campaigns. This protocol covers step 4 of its first experiment.
- **Transfer is not measured.** One codebase, planted rather than historical defects, and a
  planter from the same model family as the arms. Planted defects may be easier or harder for
  that family than real ones; the trial cannot tell which.
- **Operator effort is real.** Approval, the passphrase, and decisions on interruptions all need
  a person, and the protocol measures that time but does not reduce it.
- **It is not yet shown to work.** Until 043's trial reaches its decision, this is a protocol that
  has run, not one that has produced a result.

## Starting points

- [`043/PLAN-001`](../043_lean_harness_properties/PLAN-001-trial-lean-against-differential-checks.md),
  the plan, with its three amendments.
- [`043/trial/sequence.log`](../043_lean_harness_properties/trial/sequence.log), the record,
  including every deviation.
- [`043/trial/scripts/`](../043_lean_harness_properties/trial/scripts/), which hold:

  | Script | What it does |
  |---|---|
  | `build_tree.sh` | Builds the arms' tree |
  | `settings.py` | Writes each session's deny rules |
  | `brief.py` | Renders the briefs from the plan |
  | `launch.sh`, `clock.sh` | Start a session in herdr, then send its reminder and stop it at the cap |
  | `audit.py` | Audits a session's transcript |
  | `seal_planter.sh` | The operator's sealing step |
  | `memwatch.py` | The memory watchdog |

  The scripts are written for 043, with its paths hard-coded in `common.sh`. To reuse them, copy
  them and change `common.sh`, the target blocks in `brief.py`, and the briefs.

  The 043 files are on PR #314's branch, so these links resolve once it merges.
- [`040/EXPERIMENT.md`](https://github.com/arniwesth/motoko_agent/pull/248), an independent
  pre-registration with a fixed task sample and sealed held-out faults, in PR #248. It is still
  open.
