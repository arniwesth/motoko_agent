# 042 — Improving Motoko's Method of Experimentation

Date: 2026-11-02

Status: Research direction. The first experiment is proposed; no implementation or experimental
results are recorded yet.

## Research question

Can Motoko become better at deciding what evidence to gather next, carry that improvement into
unfamiliar investigations, and use the improved method to discover further improvements?

The proposed starting point is investigating why an existing test suite missed a defect.
Motoko would study its investigations, change its method, and compare the successor with its
predecessor on unseen problems using the same foundation model and comparable budgets.

## Documents

- [Research direction and proposed first experiment](RESEARCH-improving-experimentation.md) —
  motivation, candidate method changes, evaluation criteria, evidence boundaries and open
  questions.
- [Parent RSI direction](../../../design_docs/planned/m-motoko-dst-recursive-self-improvement.md) —
  the broader ambition of improving execution, discovery and verification.

## First milestone

Motoko discovers a weakness in how it investigates failures, changes that method, and
demonstrates better investigations on problems it had not seen.
