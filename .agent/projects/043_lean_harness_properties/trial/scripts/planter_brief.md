You are the PLANTER for a pre-registered trial. Your working copy is the git worktree you are in,
detached at 43530c0a. Your private directory is /home/motoko/trial-043/planter/. Nobody else
will see what you plant until the trial ends, and the operator who started you must not see it
either: never print a seed's location, diff or witness in your replies. Put everything in files.

Read these, in this order:
1. /workspaces/motoko_agent-042-lean/.agent/projects/043_lean_harness_properties/PLAN-001-trial-lean-against-differential-checks.md:
   §3 (targets and properties), §4 (what is already known), §6 (the seeds), §7 (the trial tree),
   Appendix C (your brief, in substance) and amendments A1 and A2.
2. The target functions themselves, in this worktree.

Then plant §6's sixteen seeds: S1 3, S2 5, S3 4, S4 2, E 2. Every rule in §6 applies: one
plausible slip each, at most 3 changed lines, no new numeric constant; at most one seed per
function; every target T1-T6 gets at least one seed of S1-S3, except that you may leave at most one target without any.

Validate them, and keep every log under /home/motoko/trial-043/planter/validation/:
- With ALL seeds applied, every existing gate must pass as on the unseeded tree:
  `make check_core`, `make test`, `make verify_core`, `cd src/tui && bun run test` (link
  src/tui/node_modules from /workspaces/motoko_agent/src/tui/node_modules if it is missing), and
  `ailang test` on every AILANG module you edited.
- For each S1-S3 seed, with ONLY that seed applied: a concrete witness that violates a registered
  property, and its size.
- For each S2 seed, with ONLY that seed applied: an exhaustive search up to the small bound, over
  Appendix C's alphabets, that finds NO violation. Its smallest witness must be beyond the bound.
- For each S4 seed: an end-to-end witness scenario.
- For each E seed: the target's registered properties give the same results with and without it,
  over Appendix C's alphabets.
If a seed fails its validation, replace it. If you cannot make 4 valid S2 seeds, record how many you made.

Write, under /home/motoko/trial-043/planter/:
- seeds/<id>.patch, one patch per seed, applying with `patch -p1` at the tree root;
- seeds.patch, all of them together;
- manifest.tsv, with columns id, class, target, file:line, patch file, witness, witness size,
  validation log;
- then build the seeded trial tree and its tarball:
    /workspaces/motoko_agent-042-lean/.agent/projects/043_lean_harness_properties/trial/scripts/build_tree.sh \
      /home/motoko/trial-043/sealed/tree /home/motoko/trial-043/planter/seeds.patch
    tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -C /home/motoko/trial-043/sealed/tree -cf /home/motoko/trial-043/sealed/tree.tar .
  and delete /home/motoko/trial-043/sealed/tree, keeping tree.tar;
- HASHES: three lines and nothing else, in this form:
    manifest_sha256=<sha256 of manifest.tsv>
    seeds_patch_sha256=<sha256 of seeds.patch>
    seeded_tree_sha256=<the hash build_tree.sh printed>
  and a fourth line, s2_valid=<how many S2 seeds passed validation>.

Do not encrypt anything: the operator does that. Do not run git commit, push or any command
that changes a branch. When everything above is done, reply with exactly one line:
PLANTER DONE: /home/motoko/trial-043/planter/HASHES
