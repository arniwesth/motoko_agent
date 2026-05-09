---
doc_type: short
full_text: sources/Misc.md
---

# Misc

This document is a miscellaneous collection of exploration ideas, feature‑plan items, and a practical note about Modal billing and account security.

## Development Exploration Ideas
- **[[concepts/ast-grep-integration]]**: Make ast‑grep support AILANG syntax.
- **[[concepts/context-compression]]**: Explore integrating Context Mode and Headroom for context compression.
- **[[concepts/openclaw-rl]]**: Investigate OpenClaw‑RL.
- **[[concepts/fine-tuning-for-ailang]]**: Fine‑tune an LLM for AILANG using Distil Labs, Tinker, or Oumi.
- **[[concepts/csp-concurrency]]**: Investigate rewriting AILANG’s core with Communicating Sequential Processes (CSP).
- **[[concepts/monty-pydantic]]**: Explore Pydantic’s Monty project.
- **[[concepts/llm-wiki]]**: Look into Karpathy’s LLM Wiki gist.
- **[[concepts/deterministic-simulation-testing]]**: Adopt Deterministic Simulation Testing as a foundation for Motoko.
- **[[concepts/phoenix-architecture]]**: Incorporate ideas from the Phoenix Architecture.

## Feature Plan Items
- Log from core to TUI
- Configuration system
- Tool registration system (Pi inspired)
- Skill registration system (Pi inspired)
- MCP registration (extension)

## Modal Billing & Security
A claim about Modal only allowing credit addition on the Team plan was found to be inaccurate: Starter includes $30/month credits and auto‑bills via the linked payment method. The main concern is the risk of runaway charges on a hacked account.

Mitigations discussed:
- Set a strict workspace budget cap.
- Use a dedicated virtual card with a hard spending limit.
- Keep GPU concurrency low.
- Rotate secrets, enforce MFA, and monitor spend daily.
- Isolate risky experiments in a separate workspace.

These practices are captured under **[[concepts/modal-cost-control]]**.