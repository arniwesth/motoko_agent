You are Motoko. This repository is your own source code. `src/core/session.ail` is the session driver that is running this conversation right now. An audience is watching this terminal.

For the next ten minutes, demonstrate Motoko's deterministic simulation testing (DST) on yourself. Show three things:

1. It is reproducible.
2. It drives your real session code through a simulated world that injects faults.
3. It catches a bug in your own driver that the type checker, the session outcome and replay itself all miss.

Then put everything back exactly as it was.

AUDIENCE_NUMBER = 42

## Rules

1. The terminal is the evidence. Every claim you make must quote the output line that shows it. If no printed line shows it, don't say it.
2. Run the commands below as written and in order. Don't run `make dst` or any other long job.
3. Keep full output in `/tmp/motoko-dst-demo/`, and show only the filtered view given here. If a filter prints nothing, read the full log before saying anything.
4. Name the test profile exactly as the `manifest:` line prints it, never from memory.
5. Between steps, say at most two plain sentences. Explain each term the first time you use it.
6. The only file you may change is `src/core/session.ail`. Change it only in Act 3, only with the command given, and make sure it is byte-identical to HEAD before you finish. Don't commit, stash or reset anything, and don't touch any other file.
7. If anything differs from what this script expects, stop, show the line and say plainly what happened. An honest surprise makes a better demo than a smoothed-over one.

## Act 0: Preflight

```bash
mkdir -p /tmp/motoko-dst-demo
git diff --quiet HEAD -- src/core/session.ail && echo "session.ail clean" || echo "DIRTY"
cat > /tmp/motoko-dst-demo/epoch.sh <<'EOF'
#!/usr/bin/env bash
# usage: epoch.sh <epoch> <label>  -- run the demo-scale rotating corpus, table seed -> identity
log=/tmp/motoko-dst-demo/epoch-$2.log
MOTOKO_DST_SCALE=demo MOTOKO_DST_EPOCH=$1 ailang run \
  --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand \
  --ai-stub --entry scheduled_run scripts/dst/corpus_rotating_dst.ail < /dev/null > "$log" 2>&1
rc=$?
grep -oE 'seed [0-9]+$|identity: [0-9a-f]{12}' "$log" | paste - - > /tmp/motoko-dst-demo/ids-$2.txt
echo "exit=$rc  $(grep -E '^(✓|✗) scheduled corpus run' "$log")"
EOF
chmod +x /tmp/motoko-dst-demo/epoch.sh
```

If the output says DIRTY, stop and say you won't run the demo on a file with uncommitted changes.

Otherwise, say one sentence about what DST means here. A seeded, simulated world (model replies, tool results, environment and clock) drives your real session code, and every interaction is recorded and checked.

## Act 1: Same seed, same world (about 70 s)

```bash
make seeded_generator > /tmp/motoko-dst-demo/1-seeded.log 2>&1; echo "exit=$?"
grep -E '^  (rich|pairA|pairB|repeat): seed=|^SEEDROW (pairA|pairB|repeat) |changing the seed changes|ignores-its-seed ←|EQUAL interaction count|^seeded generator:' /tmp/motoko-dst-demo/1-seeded.log
```

Point out:

- `pairA` and `repeat` use the same seed and produce the same digest.
- `pairB` uses a different seed. It has the same interaction count but a different digest, so the difference is in the content, not the length.
- There is a check that a generator which ignores its seed gets caught.
- The `clock=` values are simulated milliseconds. The deadlines in these runs happened in virtual time, so nobody waited for them.

## Act 2: The audience picks the world (about 10 s)

Let E = AUDIENCE_NUMBER. The demo-scale job draws 4 seeds from a 26-seed space. Before it certifies a run, it checks that its rotation wraps that space within the next six epochs, which holds only when E mod 13 is between 1 and 6. If E fails that rule, say so in one sentence and use the next number up that passes. Then:

```bash
/tmp/motoko-dst-demo/epoch.sh E a
/tmp/motoko-dst-demo/epoch.sh E b
grep -E 'window:|rot-seed|manifest:|classes:|branches:' /tmp/motoko-dst-demo/epoch-a.log
diff /tmp/motoko-dst-demo/ids-a.txt /tmp/motoko-dst-demo/ids-b.txt && echo "IDENTICAL across two processes:" && cat /tmp/motoko-dst-demo/ids-a.txt
```

Point out:

- Nobody pinned these seeds; the audience's number chose them.
- Each seed injected fault classes (`classes:`) and reached a named recovery branch in production code (`branches:`).
- The `manifest:` line is the profile you'll name from now on.
- Two separate processes produced byte-identical program identities. Ask the audience to remember the identity column.

## Act 3: Break myself (about 2½ min)

First explain the bug in two sentences. `session_policy_init`, the function that configured this very session, reads four environment variables and passes the simulated world from each read to the next. You'll make the third read start from the first read's world instead of the second's. That silently drops the record that `MOTOKO_RETRY_STREAM_ERROR` was ever read.

```bash
sed -i 's/let r_base = ports.env_get(advance(r_retry.next_state, EnvRead)/let r_base = ports.env_get(advance(r_persist.next_state, EnvRead)/' src/core/session.ail
git diff -U0 src/core/session.ail
```

Then explain why this bug is nasty:

- It type-checks.
- Against the live environment, an env read returns its input world unchanged, so a real session behaves identically and no user would ever see the bug.
- Every recording, replay and resume built on the simulated world is now missing a fact.

**3a. The type checker (about 60 s)**

```bash
ailang check src/core/session.ail 2>&1 | tail -1
```

**3b. The audience's world, again (about 5 s)**

```bash
/tmp/motoko-dst-demo/epoch.sh E mutant
diff /tmp/motoko-dst-demo/ids-a.txt /tmp/motoko-dst-demo/ids-mutant.txt; true
```

The job still prints ✓, but the same seeds now produce different bytes. Be honest about what that means. A changed identity proves that the driver's behavior at the boundary changed. It does not prove a bug, because a legitimate change would also do this. So ask the oracle next.

**3c. The oracle (about 70 s)**

```bash
make strict_replay > /tmp/motoko-dst-demo/3-strict-mutant.log 2>&1; echo "exit=$?"
grep -E '^rich: discovery recorded|✓ rich: the (discovery run ended|exact program replays|replay reproduces)|rich: the REPLAYED|^strict_replay_dst' /tmp/motoko-dst-demo/3-strict-mutant.log
grep -m1 -oE "\[discovery-env-read-under-recorded\][^;]*" /tmp/motoko-dst-demo/3-strict-mutant.log
```

Walk through it in this order:

1. The session ended Ok, so the outcome looks fine.
2. The program replays to an identical log and reproduces the terminal outcome. The bug is perfectly reproducible and self-consistent, so replay alone cannot see it.
3. The finding names `MOTOKO_RETRY_STREAM_ERROR`: 1 read was reached and 0 were recorded. A witness that the recorder did not write is what catches the bug.
4. Read the rest of that finding line in the full log and put its caveat in plain words. The expected count is derived from the driver's source and control flow, not from a runtime trap. The harness labels this as a different kind of evidence, and so should you.

## Act 4: Put it back (about 80 s)

```bash
sed -i 's/let r_base = ports.env_get(advance(r_persist.next_state, EnvRead)/let r_base = ports.env_get(advance(r_retry.next_state, EnvRead)/' src/core/session.ail
git diff --quiet HEAD -- src/core/session.ail && echo "session.ail byte-identical to HEAD" || echo "NOT RESTORED"
```

If the output says NOT RESTORED, run `git checkout -- src/core/session.ail`. That is safe because the file was clean at preflight. Check again, and say that you had to.

```bash
/tmp/motoko-dst-demo/epoch.sh E restored
diff /tmp/motoko-dst-demo/ids-a.txt /tmp/motoko-dst-demo/ids-restored.txt && echo "identities back to baseline"
make strict_replay > /tmp/motoko-dst-demo/4-strict-clean.log 2>&1; echo "exit=$?"
grep -E '^rich: discovery recorded|rich: the REPLAYED|^strict_replay_dst' /tmp/motoko-dst-demo/4-strict-clean.log
```

Point out:

- The identities returned to exactly the Act 2 baseline.
- strict_replay passes.
- Discovery recorded one more interaction than it did with the bug in place: the missing env read.

## Act 5: What this green does and does not mean (about 10 s)

```bash
make fault_catalogue > /tmp/motoko-dst-demo/5-faults.log 2>&1; echo "exit=$?"
grep -E 'shipped catalogue validates|driver_only installs none' /tmp/motoko-dst-demo/5-faults.log
sed -n '/recorded coverage gap/,/physical-fault/p' /tmp/motoko-dst-demo/5-faults.log
```

Finish with three things.

1. **A scorecard table.** Use the columns "check", "clean" and "with the bug", and include rows for the type check, the audience-world job, the seed identities and strict_replay. Use only values you observed.
2. **"What this does not show."** Write three bullets, each tied to a printed line:
   - Coverage is claimed per profile. Name the profile, and note that it installs no extensions, as the `extension_effect_fault` waiver line says.
   - The fault catalogue records its own coverage gaps. Quote them.
   - DST checks that the harness handles a specified sequence of observations correctly. It says nothing about model quality or whether a live task succeeds.
3. **One closing sentence, and no more,** on why this matters for an agent that edits its own code: before a harness can safely change itself, it has to be able to catch itself.
