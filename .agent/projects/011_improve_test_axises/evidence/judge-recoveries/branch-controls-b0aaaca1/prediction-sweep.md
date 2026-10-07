Written 2026-10-07T13:33:09Z, in the sweep's first minute and before any result of it was read.
Tree: b0aaaca1 plus the two scripts and the documents (patch sha256 5fa2067952f2425b).

Predicted: make dst exits 0 and its summary reads "all targets passed" with no note. The change is
in two scripts under scripts/dst and touches nothing under src/core, so no target but corpus_pr and
corpus_judge runs different code, and both of those were run alone and passed.
What would make me wrong: a target that reads the documents I edited, or one that imports
corpus_pr_dst and depends on its runtime being built the old way.
