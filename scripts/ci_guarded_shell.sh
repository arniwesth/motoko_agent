#!/usr/bin/env bash
# ci_guarded_shell.sh SCRIPT
#
# The `shell:` of every run step in verify-extensions.yml, set once as the
# workflow's `defaults.run.shell: bash scripts/ci_guarded_shell.sh {0}`. It runs
# the step's script exactly as `shell: bash` would (bash --noprofile --norc -eo
# pipefail) and sends stdout and stderr through scripts/line_guard.sh 16384
# --strict, so no line longer than 16384 characters reaches the runner and a
# step that prints one goes red naming it. line_guard.sh says why a long line
# is a hang rather than a slow step.
#
# PIPEFAIL IS THE LOAD-BEARING PART. Without it this pipeline's status is the
# guard's, and a failing step with clean output reports green (measured: rc=0
# without, rc=3 with). With it, a failing step always fails the pipeline, with
# its own status unless the guard fails too (then the guard's 1: red either
# way).
#
# The path is relative to the workspace, which is every step's working
# directory unless the step sets `working-directory:` -- so no step here does;
# one that needs another directory `cd`s inside its script.
#
# LINE_GUARD_MUTANT, set only by the workflow_dispatch input of that name,
# writes one 1 MB line to stderr before the step runs: the mutation that must
# turn a guarded step red, fast and by name, in every job.
set -o pipefail

here=$(dirname "${BASH_SOURCE[0]}")

{
  if [ -n "${LINE_GUARD_MUTANT:-}" ]; then
    head -c 1048576 /dev/zero | tr '\0' x >&2
    echo >&2
  fi
  bash --noprofile --norc -eo pipefail "$1"
} 2>&1 | "$here/line_guard.sh" 16384 --strict
