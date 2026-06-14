# The AI Scientist: Prior Art for Layer 1 (Researcher Automation)

## Source

"Towards end-to-end automation of AI research" — *Nature* (2026),
[s41586-026-10265-5](https://www.nature.com/articles/s41586-026-10265-5). The
peer-reviewed consolidation of **The AI Scientist** (Sakana AI), originally
[arXiv:2408.06292](https://arxiv.org/abs/2408.06292). Author overlap with the
Darwin Gödel Machine — **Cong Lu, Robert Lange, Jeff Clune** — places both
papers in one research program, not as independent results.

## Why This Belongs in the Research

The branch already anchors **Layer 2** (Motoko edits its own hooks) in the
Darwin Gödel Machine. It does *not* yet ground **Layer 1** (Motoko as the
autonomous researcher — see [02-recursive-self-improvement.md](./02-recursive-self-improvement.md))
in any published system. The AI Scientist is that missing anchor: the canonical
demonstration of automating the *research process itself*. This document maps it
to Motoko's Layer 1, extracts the one finding that is directly actionable for the
first experiment (the Automated Reviewer as a calibrated fitness signal), and
reconciles two claims it shares a boundary with — DGM's evaluator-hardening rule
and the RFC's "de-correlated from model capability" framing.

## What The AI Scientist Is

A pipeline that runs the scientific process end to end with a **frozen** agent:
it *"autonomously generates novel research ideas, searches for and reads the
relevant literature, designs, programs, and conducts experiments via parallelized
agentic tree search, and writes the entire paper,"* then evaluates the result
with an **Automated Reviewer**.

Reported headline results:

| Element | Result |
|---|---|
| **Automated Reviewer accuracy** | **69% balanced accuracy** — "comparable to human reviewers" |
| **Reviewer vs. humans** | F1 *"exceeded the inter-human agreement measured in the famous NeurIPS 2021 consistency experiment"* |
| **Peer-review milestone** | An AI-generated paper scored **6.33** (individual: 6, 7, 6) at an ICLR 2025 workshop — *"higher than 55% of human-authored papers"* |
| **Scaling law of science** | *"as the underlying foundation models improve, the quality of the generated papers increases correspondingly"* |

## The Different Axis: Layer 1 vs. Layer 2

The AI Scientist and DGM automate *different layers*, and Motoko's three-layer
analysis already named both. This is the key to where each fits:

| Axis | Paper | Frozen | Improves | Motoko layer |
|---|---|---|---|---|
| **Do the research** | AI Scientist | the agent / harness | research output (papers) | **Layer 1** — Motoko as the researcher |
| **Improve the researcher** | Darwin Gödel Machine | the foundation model | the agent's own codebase | **Layer 2** — Motoko edits its own hooks |

They compose. The endgame Motoko sketches — an agent that *does* the research and
*improves its own ability to do it* — is exactly the union: AI Scientist's task
under DGM's self-modification loop. DGM even states this thesis directly
("improving its ability to modify its own codebase"). Layer 1 is the work; Layer
2 is getting better at the work. The branch should cite AI Scientist as the
Layer-1 anchor the way it cites DGM as the Layer-2 anchor.

## The One Directly Actionable Finding: a Calibrated Fitness Signal

The hardest unsolved problem in the RFC is the **improvement signal**
([04-layer-2-discussion.md](./04-layer-2-discussion.md) §5.2,
[02-recursive-self-improvement.md](./02-recursive-self-improvement.md) §2). The
current answer is a crude scalar composite — `success_rate × 100 - cost / 1000` —
and the analysis explicitly flags subjective dimensions like *"report quality"*
as **Low** amenability because they resist measurement.

The Automated Reviewer is an existence proof for the way out: an LLM-judge
evaluator **calibrated against human reviewers** (69% balanced accuracy; F1 above
NeurIPS 2021 inter-human agreement). For the dimensions Motoko would otherwise
drop, this is a richer fitness signal than token-count arithmetic — and it is
validated, not assumed.

**The catch — and it is load-bearing.** This signal collides with the
reward-hacking result verified in [05-darwin-godel-machine.md](./05-darwin-godel-machine.md):
if the agent can edit its own reviewer, it games the reviewer instead of
improving the work (DGM's Appendix H, node 114). So an automated-reviewer fitness
signal is only safe **outside the agent's mutation scope** — the exact
evaluator-boundary rule doc 05 argues, now made concrete. The two papers
reinforce each other: AI Scientist supplies the richer signal; DGM supplies the
constraint on where it must live. If Motoko adopts an LLM-judge for report
quality, the judge, its prompt, and its rubric must be immutable from — and
ideally invisible to — the hooks during self-modification.

## Reconciling Two Claims

### 1. "De-correlated from model capability" needs precise wording

The RFC claims hook improvements are *"de-correlated from model capability"*;
DGM supports this (improvements transfer across foundation models). But AI
Scientist reports a **"scaling law of science"** — output quality *rises* with FM
capability. Both are true and the RFC should state the distinction exactly:

- The **harness optimization is model-independent** (DGM): a tool policy that
  redirects `find | grep` to `Search` saves tokens on any model.
- The **quality ceiling rises with the model** (AI Scientist): a better FM
  produces better work through the same harness.

"De-correlated" should mean *the optimization is real regardless of model* — not
*the model doesn't matter*. Both levers are worth pulling; they are orthogonal.

### 2. Cite the peer-review milestone honestly

The 6.33 / "better than 55% of human papers" result is a workshop-tier
submission, and the AI Scientist line of work drew
[substantive criticism](https://arxiv.org/html/2502.14297v2) on whether it
constitutes genuine discovery. Cite it as a milestone with caveats, not a clean
win. For Motoko's purposes the durable contribution is the **Automated Reviewer
methodology and its human-calibration numbers**, not the headline paper score.

## Net Implications for Motoko

1. **Anchor Layer 1 in AI Scientist.** It is the published existence proof that
   the researcher-automation layer (doc 02 Layer 1, the AutoGo-driver role) is
   tractable. Reference it first for that layer, as DGM is referenced first for
   Layer 2.

2. **Consider an LLM-judge for the subjective metrics** the scalar composite
   can't capture (report quality, analysis coherence). AI Scientist shows it can
   be calibrated against humans well enough to use as a selection signal.

3. **Bind the judge to the evaluator boundary.** Any LLM-judge fitness signal
   inherits DGM's reward-hacking risk and must sit outside the mutation scope —
   same rule as the metric collector, task runner, and `make check_core`.

4. **State the model-capability relationship precisely** in the RFC: harness
   gains transfer across models (DGM); the quality ceiling scales with the model
   (AI Scientist). Keep both, and don't conflate "de-correlated" with "irrelevant."

## References

- [Towards end-to-end automation of AI research (*Nature* 2026)](https://www.nature.com/articles/s41586-026-10265-5)
- [The AI Scientist, now in *Nature* — Sakana AI](https://sakana.ai/ai-scientist-nature/)
- [The AI Scientist (arXiv:2408.06292)](https://arxiv.org/abs/2408.06292) — original
- [Critical evaluation of the AI Scientist (arXiv:2502.14297)](https://arxiv.org/html/2502.14297v2)
- [05-darwin-godel-machine.md](./05-darwin-godel-machine.md) — Layer-2 prior art; evaluator-boundary rule and reward-hacking finding
- [02-recursive-self-improvement.md](./02-recursive-self-improvement.md) — three-layer analysis (Layer 1 defined here)
- [04-layer-2-discussion.md](./04-layer-2-discussion.md) — the Layer-2 RFC; signal-design problem (§5.2)
