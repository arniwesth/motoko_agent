# Shared settings for the trial's operator scripts (PLAN-001, amendment A1).
ROOT="${TRIAL_ROOT:-/home/motoko/trial-043}"
BASE=43530c0a
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$SCRIPTS/../.." && pwd)"                 # .agent/projects/043_lean_harness_properties
REPO="$(git -C "$SCRIPTS" rev-parse --show-toplevel)"
PLAN="$PROJECT/PLAN-001-trial-lean-against-differential-checks.md"
MODEL=claude-opus-5-5
EFFORT=xhigh
# Every session the trial can have, so each one's deny rules can name all the others.
ALL_SESSIONS="t043-dry-a t043-dry-b $(for t in 1 2 3 4 5 6; do for r in a1 a2 b1 b2; do printf 't043-t%s-%s ' $t $r; done; done)"
hash_dir() { # deterministic sha256 of a directory's contents
  tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -C "$1" -cf - . | sha256sum | cut -d' ' -f1
}
